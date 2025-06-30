<<<<<<< HEAD
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
=======
require 'bundler/setup'
Bundler.require
require 'selenium-webdriver'
require 'webdrivers'
require 'dotenv'

Dotenv.load

def check_env_variables
  %w[TWITTER_USERNAME TWITTER_PASSWORD TWITTER_EMAIL].each do |var|
    puts "  #{var} #{ENV[var]&.empty? ? 'n\'est pas défini ou est vide' : 'est défini (valeur masquée)'}"
  end
end

def login_to_twitter(driver, username, password)
  driver.navigate.to "https://twitter.com/login"
  wait = Selenium::WebDriver::Wait.new(timeout: 30)

  wait.until { driver.find_element(css: 'input[name="text"]') }.send_keys(username, :enter)
  wait.until { driver.find_element(css: 'input[name="password"]') }.send_keys(password, :enter)
  wait.until { driver.find_element(css: 'div[data-testid="primaryColumn"]') }
  puts "Connexion réussie"
rescue StandardError => e
  puts "Erreur lors de la connexion : #{e.message}"
end

def close_popups(driver)
  begin
    # Fermer le pop-up de consentement aux cookies, s'il est présent
    wait = Selenium::WebDriver::Wait.new(timeout: 5)
    popup = wait.until { driver.find_element(css: 'div[data-testid="cookieBanner"]') }
    popup.click
  rescue Selenium::WebDriver::Error::NoSuchElementError, Selenium::WebDriver::Error::TimeoutError
    # Ignorer s'il n'y a pas de pop-up
  end
end

def publish_tweets(driver, tweets)
  wait = Selenium::WebDriver::Wait.new(timeout: 30)

  tweets.each_with_index do |tweet_text, index|
    begin
      # Faire défiler la page pour s'assurer que le bouton est visible
      driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")

      # Fermer les pop-ups potentiels
      close_popups(driver)

      # Attendre que le bouton "Nouveau Tweet" soit visible et cliquable
      wait.until { driver.find_element(css: 'a[data-testid="SideNav_NewTweet_Button"]') }.click
      sleep 3

      textarea = wait.until { driver.find_element(css: 'div[data-testid="tweetTextarea_0"]') }

      # Ajouter le texte du tweet
      textarea.send_keys(tweet_text)
      textarea.send_keys("\n#PubliéParChatGPT")  # Ajout du marqueur pour identifier les tweets publiés

      # Cliquer sur le bouton de publication du tweet
      publish_button = wait.until { driver.find_element(css: 'div[data-testid="tweetButtonInline"]') }
      publish_button.click
      puts "Tweet publié avec succès : #{tweet_text}"

      # Enregistrer l'index du tweet publié
      write_last_published_index(index)

      # Attendre quelques secondes avant de publier le tweet suivant
      sleep 5
    rescue Selenium::WebDriver::Error::ElementClickInterceptedError => e
      puts "Erreur lors de la publication du tweet : #{e.message}"
      # Retenter le clic après un délai en cas d'interception
      sleep 2
    rescue StandardError => e
      puts "Erreur lors de la publication du tweet : #{e.message}"
    end
  end
end

def get_latest_tweets_from_csv(file_path)
  tweets = []

  File.foreach(file_path) do |line|
    line = line.strip
    # On considère une ligne comme un tweet si elle commence par un tiret ou un point
    if line.start_with?("-", "•")
      tweets << line.strip
    end
  end

  if tweets.empty?
    puts "Pas de tweets trouvés dans le fichier."
    return []
  end

  # Lire l'index du dernier tweet publié
  last_published_index = read_last_published_index

  # Si aucun index valide n'est trouvé, commencer à publier depuis le début
  start_index = last_published_index ? last_published_index + 1 : 0

  # Récupérer les tweets à publier
  tweets_to_publish = tweets[start_index..-1]
  tweets_to_publish
end

def read_last_published_index
  if File.exist?('last_published_index.txt')
    index = File.read('last_published_index.txt').to_i
    return index if index >= 0
  end
  nil
end

def write_last_published_index(index)
  File.write('last_published_index.txt', index)
end

begin
  puts "Démarrage du script"
  check_env_variables

  %w[TWITTER_USERNAME TWITTER_PASSWORD TWITTER_EMAIL].each do |var|
    raise "#{var} n'est pas défini ou est vide" if ENV[var]&.empty?
  end

  options = Selenium::WebDriver::Chrome::Options.new(args: ['--start-maximized'])
  driver = Selenium::WebDriver.for(:chrome, options: options)

  login_to_twitter(driver, ENV['TWITTER_USERNAME'], ENV['TWITTER_PASSWORD'])

  tweets_to_publish = get_latest_tweets_from_csv('tweets_final.csv')

  if tweets_to_publish.empty?
    puts "Aucun tweet à publier."
  else
    puts "Tweets à publier :\n#{tweets_to_publish.join("\n")}"
    publish_tweets(driver, tweets_to_publish)
  end
rescue StandardError => e
  puts "Une erreur est survenue : #{e.message}"
  puts e.backtrace
ensure
  driver&.quit
end
>>>>>>> 5c5dfac1cd9e16d54ed76970e6263e96b1e0e76f
