require_relative 'twitter_bot'
require_relative 'config'

class TwitterPublisher < TwitterBot
  def initialize
    super
  end

  def publish_tweets
    safe_execute("Publication des tweets") do
      setup_driver
      login_to_twitter
      
      tweets = load_tweets_to_publish
      return logger.info("Aucun tweet à publier") if tweets.empty?

      # Limiter à 7 tweets maximum
      tweets = tweets.first(7)
      logger.info("Publication de #{tweets.size} tweets (max 7)")
      
      tweets.each_with_index do |tweet, index|
        publish_single_tweet(tweet, index)
        
        # Délai anti-blocage entre les tweets
        if index < tweets.size - 1
          delay = calculate_anti_block_delay(index)
          logger.info("Attente de #{delay} secondes avant le prochain tweet...")
          sleep(delay)
        end
      end
      
      logger.info("Publication terminée avec succès!")
    end
  ensure
    close
  end

  private

  def load_tweets_to_publish
    tweets = extract_tweets_from_file
    return [] if tweets.empty?

    last_index = read_last_published_index
    start_index = last_index ? last_index + 1 : 0
    tweets[start_index..-1] || []
  end

  def extract_tweets_from_file
    return [] unless File.exist?(TwitterBotConfig::FILES[:tweets_final])

    File.readlines(TwitterBotConfig::FILES[:tweets_final])
        .map(&:strip)
        .select { |line| line.start_with?('-', '•') }
        .map { |line| line.gsub(/^[-•]\s*/, '') }
  end

  def publish_single_tweet(tweet_text, index)
    safe_execute("Publication du tweet #{index + 1}/7") do
      # Comportement humain : pause aléatoire avant de commencer
      random_delay(2, 4)
      close_popups
      
      # Cliquer sur le bouton nouveau tweet
      new_tweet_button = @wait.until { @driver.find_element(css: 'a[data-testid="SideNav_NewTweet_Button"]') }
      simulate_human_behavior
      new_tweet_button.click
      random_delay(1, 2)
      
      # Taper le texte de manière humaine
      textarea = @wait.until { @driver.find_element(css: 'div[data-testid="tweetTextarea_0"]') }
      human_type(textarea, tweet_text, delay_range: 0.03..0.08)
      random_delay(1, 3)
      
      # Publier le tweet
      publish_button = @wait.until { @driver.find_element(css: 'div[data-testid="tweetButtonInline"]') }
      simulate_human_behavior
      publish_button.click
      
      # Attendre la confirmation
      random_delay(2, 4)
      update_last_published_index(index)
      
      logger.info("✅ Tweet #{index + 1}/7 publié: #{tweet_text[0..50]}...")
    end
  rescue StandardError => e
    logger.error("❌ Échec publication tweet #{index + 1}: #{e.message}")
    random_delay(5, 10)
  end

  def calculate_anti_block_delay(tweet_index)
    # Délais progressifs pour éviter la détection
    base_delays = [30, 45, 60, 90, 120, 180] # secondes
    delay = base_delays[tweet_index] || 180
    
    # Ajouter une variation aléatoire de ±20%
    variation = delay * 0.2
    actual_delay = delay + rand(-variation..variation)
    
    actual_delay.to_i
  end

  def read_last_published_index
    return nil unless File.exist?(TwitterBotConfig::FILES[:last_index])
    
    index = File.read(TwitterBotConfig::FILES[:last_index]).to_i
    index >= 0 ? index : nil
  end

  def update_last_published_index(index)
    File.write(TwitterBotConfig::FILES[:last_index], index)
  end
end

if __FILE__ == $PROGRAM_NAME
  publisher = TwitterPublisher.new
  publisher.publish_tweets
end