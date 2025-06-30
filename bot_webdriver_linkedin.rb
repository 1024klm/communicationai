require 'bundler/setup'
Bundler.require
require 'selenium-webdriver'
require 'webdrivers'
require 'dotenv'
require 'pry'

# Chargement des variables d'environnement depuis le fichier .env
Dotenv.load

# Définition des constantes pour les informations de connexion
LINKEDIN_USERNAME = ENV['LINKEDIN_EMAIL']
LINKEDIN_PASSWORD = ENV['LINKEDIN_PASSWORD']

def login_to_linkedin
  options = Selenium::WebDriver::Chrome::Options.new
  # options.add_argument('--headless')  # Commentez cette ligne pour voir le navigateur

  puts "Initialisation du driver Chrome..."
  driver = Selenium::WebDriver.for :chrome, options: options
  wait = Selenium::WebDriver::Wait.new(timeout: 30)

  begin
    puts "Accès à la page de connexion LinkedIn..."
    driver.get 'https://www.linkedin.com/login'
    sleep 3  # Attente de 3 secondes

    puts "Recherche du champ email..."
    email_field = wait.until { driver.find_element(id: 'username') }
    email_field.send_keys(LINKEDIN_USERNAME)

    puts "Recherche du champ mot de passe..."
    password_field = driver.find_element(id: 'password')
    password_field.send_keys(LINKEDIN_PASSWORD)

    puts "Clic sur le bouton de connexion..."
    submit_button = wait.until { 
      element = driver.find_element(xpath: "//button[@type='submit']")
      element if element.displayed? && element.enabled?
    }
    submit_button.click

    puts "Attente de la page d'accueil..."
    sleep 10  # Augmenté à 10 secondes

    puts "URL actuelle après connexion : #{driver.current_url}"
    puts "Titre de la page : #{driver.title}"

    if driver.find_elements(css: '.challenge-dialog').size > 0
      puts "Une vérification supplémentaire est requise. Intervention manuelle nécessaire."
      sleep 30  # Donnez du temps pour une intervention manuelle
    end

    # Vérification de plusieurs éléments possibles après la connexion
    success = wait.until {
      driver.find_element(css: 'input[placeholder="Rechercher"]') ||
      driver.find_element(css: '.feed-identity-module') ||
      driver.find_element(css: '.nav-item--messaging') ||
      driver.find_element(css: '.global-nav__me-photo') ||
      driver.find_element(css: '.global-nav__primary-items')
    }
   
    puts "Connexion réussie!"
    driver.save_screenshot('linkedin_after_login.png')
   
  rescue Selenium::WebDriver::Error::TimeoutError => e
    puts "Erreur de timeout : #{e.message}"
    driver.save_screenshot('linkedin_timeout_error.png')
    puts "Capture d'écran sauvegardée dans 'linkedin_timeout_error.png'"
  rescue Selenium::WebDriver::Error::NoSuchElementError => e
    puts "Élément non trouvé : #{e.message}"
    driver.save_screenshot('linkedin_element_not_found.png')
    puts "Capture d'écran sauvegardée dans 'linkedin_element_not_found.png'"
  rescue => e
    puts "Erreur inattendue : #{e.message}"
    driver.save_screenshot('linkedin_unexpected_error.png')
    puts "Capture d'écran sauvegardée dans 'linkedin_unexpected_error.png'"
  ensure
    puts "Fermeture du navigateur..."
    driver.quit
  end
end

login_to_linkedin