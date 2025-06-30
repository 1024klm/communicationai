require 'selenium-webdriver'
require 'webdrivers'
require_relative 'base_bot'
require_relative 'config'

class TwitterBot < BaseBot
  def initialize
    super
    @driver = nil
  end

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    
    # Configuration anti-détection avancée
    options.add_argument('--headless=new') unless ENV['DEBUG']
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_argument('--disable-features=IsolateOrigins,site-per-process')
    options.add_argument('--window-size=1920,1080')
    options.add_argument('--start-maximized')
    options.add_argument('--disable-notifications')
    options.add_argument('--disable-popup-blocking')
    
    # User agent réaliste et récent
    user_agents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    ]
    options.add_argument("--user-agent=#{user_agents.sample}")
    
    # Préférences Chrome avancées
    prefs = {
      'credentials_enable_service' => false,
      'profile.password_manager_enabled' => false,
      'profile.default_content_setting_values.notifications' => 2,
      'excludeSwitches' => ['enable-automation'],
      'useAutomationExtension' => false
    }
    options.add_preference(:prefs, prefs)
    options.add_experimental_option('excludeSwitches', ['enable-automation'])
    options.add_experimental_option('useAutomationExtension', false)
    
    
    @driver = Selenium::WebDriver.for(:chrome, options: options)
    @wait = Selenium::WebDriver::Wait.new(timeout: TwitterBotConfig::TIMEOUTS[:default])
    
    # Script anti-détection basique
    @driver.execute_cdp('Page.addScriptToEvaluateOnNewDocument', {
      source: "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
    })
    
    # Ajouter des délais aléatoires pour simuler un comportement humain
    random_delay(1, 3)
  end

  def login_to_twitter
    validate_env_vars('TWITTER_USERNAME', 'TWITTER_PASSWORD')
    
    retry_with_backoff("Connexion à Twitter") do
      @driver.navigate.to "https://twitter.com/login"
      random_delay(1, 3)
      
      username_input = @wait.until { @driver.find_element(css: 'input[name="text"]') }
      human_type(username_input, ENV['TWITTER_USERNAME'])
      username_input.send_keys(:enter)
      random_delay(2, 4)
      
      password_input = @wait.until { @driver.find_element(css: 'input[name="password"]') }
      human_type(password_input, ENV['TWITTER_PASSWORD'])
      password_input.send_keys(:enter)
      random_delay(3, 5)
      
      @wait.until { @driver.find_element(css: 'div[data-testid="primaryColumn"]') }
    end
  end

  def close
    @driver&.quit
  end

  protected

  def scroll_and_wait
    @driver.execute_script('window.scrollTo(0, document.body.scrollHeight);')
    random_delay(TwitterBotConfig::DELAYS[:scroll_wait] - 1, TwitterBotConfig::DELAYS[:scroll_wait] + 1)
  end

  def close_popups
    @driver.find_elements(css: '[aria-label="Close"]').each(&:click)
  rescue
    # Ignorer les erreurs de popup
  end

  def random_delay(min_seconds, max_seconds)
    delay = rand(min_seconds..max_seconds)
    sleep(delay)
  end

  def human_type(element, text, delay_range: 0.05..0.15)
    text.chars.each do |char|
      element.send_keys(char)
      sleep(rand(delay_range))
    end
  end

  def simulate_human_behavior
    # Mouvements de souris aléatoires
    @driver.execute_script("
      function randomMouseMove() {
        const x = Math.random() * window.innerWidth;
        const y = Math.random() * window.innerHeight;
        const event = new MouseEvent('mousemove', { clientX: x, clientY: y });
        document.dispatchEvent(event);
      }
      randomMouseMove();
    ")
    random_delay(0.5, 2)
  end
end