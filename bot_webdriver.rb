require 'csv'
require 'time'
<<<<<<< HEAD
require_relative 'twitter_bot'
require_relative 'config'

class TwitterScraper < TwitterBot
  def initialize
    super
  end

  def scrape_tweets
    safe_execute("Récupération des tweets") do
      setup_driver
      login_to_twitter
      save_tweets_to_csv
    end
  ensure
    close
  end

  private

  def scrape_account_tweets(account)
    safe_execute("Récupération tweets de @#{account}") do
      navigate_to_profile(account)
      collect_today_tweets
    end
  rescue StandardError => e
    logger.error("Erreur pour @#{account}: #{e.message}")
    []
  end

  def navigate_to_profile(account)
    @driver.navigate.to("https://twitter.com/#{account}")
    @wait.until { @driver.find_element(css: 'article') }
  end

  def collect_today_tweets
    tweets = []
    last_height = 0
    scroll_attempts = 0
    max_scrolls = 10

    while scroll_attempts < max_scrolls
      current_tweets = extract_tweets_from_page
      new_today_tweets = current_tweets.select { |tweet| from_today?(tweet[:time]) }
      
      tweets.concat(new_today_tweets.map { |t| t[:text] })
      
      break if no_new_content?(last_height) || new_today_tweets.empty?
      
      scroll_and_wait
      scroll_attempts += 1
      last_height = @driver.execute_script('return document.body.scrollHeight')
    end

    tweets.uniq.compact
  end

  def extract_tweets_from_page
    @driver.find_elements(css: 'article').filter_map do |article|
      tweet_text = safe_extract_text(article, 'div[lang]')
      tweet_time = safe_extract_datetime(article, 'time')
      
      next unless tweet_text && tweet_time
      
      { text: tweet_text, time: tweet_time }
    end
  end

  def safe_extract_text(element, selector)
    element.find_element(css: selector).text
  rescue
    nil
  end

  def safe_extract_datetime(element, selector)
    datetime_attr = element.find_element(css: selector).attribute('datetime')
    Time.parse(datetime_attr) if datetime_attr
  rescue
    nil
  end

  def from_today?(time)
    return false unless time
    time.to_date == Date.today
  end

  def no_new_content?(last_height)
    current_height = @driver.execute_script('return document.body.scrollHeight')
    current_height == last_height
  end

  def save_tweets_to_csv
    CSV.open(TwitterBotConfig::FILES[:tweets_raw], "w") do |csv|
      csv << ["Account", "Tweet"]
      
      TwitterBotConfig::ACCOUNTS_TO_MONITOR.each do |account|
        tweets = scrape_account_tweets(account)
        tweets.each { |tweet| csv << [account, tweet] }
        logger.info("#{tweets.size} tweets récupérés pour @#{account}")
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  scraper = TwitterScraper.new
  scraper.scrape_tweets
end
=======

ACCOUNTS_TO_MONITOR = %w[coinacademy_fr LeJournalDuCoin Paul_Theway wallstreetbets crypto_Futur GoodValueCrypto DeepWhale_ Crypto__Goku CryptoPicsou XFenaux CFarmeur FranceCryptos captaincrypto21 CryptoastMedia MoneyRadar_fr PowerHasheur]

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

# Fonction pour défiler vers le bas de la page
def scroll_down(driver)
  driver.execute_script('window.scrollTo(0, document.body.scrollHeight);')
end

# Fonction pour vérifier si un tweet est du jour
def tweet_of_the_day?(tweet_time_text)
  return true if tweet_time_text.include?("s") || tweet_time_text.include?("min") || tweet_time_text.include?("h")
  today = Date.today
  tweet_time_text.include?("il y a 1 j") == false && tweet_time_text.include?(today.strftime("%d %b"))
end

# Fonction pour récupérer les tweets récents d'un compte
def fetch_tweets(driver, account)
  puts "Fetching tweets for #{account}"
  driver.navigate.to "https://twitter.com/#{account}"
  wait = Selenium::WebDriver::Wait.new(timeout: 30)
  wait.until { driver.find_element(css: 'article') }
  binding.pry

  tweets = []
  last_height = driver.execute_script('return document.body.scrollHeight')

  loop do
    driver.find_elements(css: 'article').each do |article|
      tweet_text = article.find_element(css: 'div[lang]').text rescue nil
      tweet_time_text = article.find_element(css: 'time').attribute('datetime') rescue nil

      if tweet_text && tweet_time_text
        tweet_time = Time.parse(tweet_time_text)
        if tweet_time.to_date == Date.today
          tweets << tweet_text
        end
      end
    end

    scroll_down(driver)
    sleep(2)  # Attente pour permettre à la page de charger plus de tweets
    new_height = driver.execute_script('return document.body.scrollHeight')
    break if new_height == last_height  # Arrêter si aucun nouveau contenu n'est chargé
    last_height = new_height
  end

  tweets
rescue StandardError => e
  puts "Error for #{account}: #{e.class} - #{e.message}"
  []
end

# Lancement du driver et création du fichier CSV
driver = Selenium::WebDriver.for :chrome
CSV.open("tweets_du_jour.csv", "wb") do |csv|
  csv << ["Account", "Tweet"]
  ACCOUNTS_TO_MONITOR.each do |account|
    fetch_tweets(driver, account).each { |tweet| csv << [account, tweet] }
  end
end

puts "Tweets successfully saved to tweets_du_jour.csv"
driver.quit
>>>>>>> 5c5dfac1cd9e16d54ed76970e6263e96b1e0e76f
