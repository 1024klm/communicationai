require_relative 'twitter_bot'
require_relative 'config'
require 'csv'
require 'date'
require 'httparty'
require 'nokogiri'

class TwitterScraper < TwitterBot
  def initialize
    super
    @scraped_data = []
  end

  def scrape_all_sources
    safe_execute("Scraping complet des sources") do
      setup_driver
      
      # Scraper les tweets
      scrape_twitter_accounts
      
      # Scraper les articles de sites crypto
      scrape_crypto_news_sites
      
      # Sauvegarder les données
      save_scraped_data
    end
  ensure
    close
  end

  private

  def scrape_twitter_accounts
    logger.info("Début du scraping des comptes Twitter")
    
    TwitterBotConfig::ACCOUNTS_TO_MONITOR.each do |account|
      safe_execute("Scraping du compte @#{account}") do
        scrape_account(account)
        random_delay(3, 5)
      end
    end
  end

  def scrape_account(account)
    @driver.navigate.to "https://twitter.com/#{account}"
    random_delay(2, 4)
    
    # Attendre le chargement de la timeline
    @wait.until { @driver.find_element(css: 'article[data-testid="tweet"]') }
    
    tweets_scraped = 0
    last_height = 0
    
    while tweets_scraped < 10
      # Récupérer les tweets actuellement visibles
      tweets = @driver.find_elements(css: 'article[data-testid="tweet"]')
      
      tweets.each do |tweet|
        next if tweet_already_scraped?(tweet)
        
        tweet_data = extract_tweet_data(tweet, account)
        if tweet_data && is_recent_tweet?(tweet_data[:timestamp])
          @scraped_data << tweet_data
          tweets_scraped += 1
          logger.info("Tweet scraped de @#{account}: #{tweet_data[:text][0..50]}...")
        end
        
        break if tweets_scraped >= 10
      end
      
      # Scroll pour charger plus de tweets
      current_height = @driver.execute_script("return document.body.scrollHeight")
      break if current_height == last_height
      
      scroll_and_wait
      last_height = current_height
    end
  end

  def extract_tweet_data(tweet_element, account)
    text = tweet_element.find_element(css: 'div[data-testid="tweetText"]').text
    timestamp = extract_tweet_timestamp(tweet_element)
    
    {
      source: "@#{account}",
      text: clean_tweet_text(text),
      timestamp: timestamp,
      type: 'tweet',
      scraped_at: DateTime.now
    }
  rescue => e
    logger.error("Erreur extraction tweet: #{e.message}")
    nil
  end

  def extract_tweet_timestamp(tweet_element)
    # Trouver l'élément time dans le tweet
    time_element = tweet_element.find_element(css: 'time')
    datetime_str = time_element.attribute('datetime')
    DateTime.parse(datetime_str)
  rescue => e
    logger.error("Erreur extraction timestamp: #{e.message}")
    DateTime.now
  end

  def clean_tweet_text(text)
    text.gsub(/\s+/, ' ').strip
  end

  def is_recent_tweet?(timestamp)
    # Considérer les tweets des dernières 24 heures
    (DateTime.now - timestamp).to_f < 1
  end

  def tweet_already_scraped?(tweet_element)
    text = tweet_element.find_element(css: 'div[data-testid="tweetText"]').text rescue ""
    @scraped_data.any? { |data| data[:text] == clean_tweet_text(text) }
  end

  def scrape_crypto_news_sites
    logger.info("Scraping des sites crypto désactivé - focus sur Twitter uniquement")
  end

  def save_scraped_data
    filename = TwitterBotConfig::FILES[:tweets_raw]
    
    CSV.open(filename, 'w', headers: true) do |csv|
      csv << ['source', 'type', 'text', 'timestamp', 'url', 'scraped_at']
      
      @scraped_data.each do |data|
        csv << [
          data[:source],
          data[:type],
          data[:text],
          data[:timestamp],
          data[:url],
          data[:scraped_at]
        ]
      end
    end
    
    logger.info("#{@scraped_data.size} éléments sauvegardés dans #{filename}")
  end
end

if __FILE__ == $PROGRAM_NAME
  scraper = TwitterScraper.new
  scraper.scrape_all_sources
end