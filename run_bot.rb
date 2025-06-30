#!/usr/bin/env ruby

require_relative 'base_bot'
require_relative 'bot_webdriver'
require_relative 'bot_chatgpt'
require_relative 'bot_publish'

class BotRunner < BaseBot
  def initialize
    super
    logger.info("Démarrage du bot Twitter d'actualités crypto")
    logger.info("=" * 50)
  end

  def run
    safe_execute("Exécution complète du bot") do
      scrape_tweets
      generate_summary
      publish_tweets
      logger.info("Bot exécuté avec succès!")
    end
  end

  private

  def scrape_tweets
    safe_execute("Étape 1: Récupération des tweets") do
      scraper = TwitterScraper.new
      scraper.scrape_tweets
    end
  end

  def generate_summary
    safe_execute("Étape 2: Génération des résumés") do
      chatgpt_bot = ChatGPTBot.new
      chatgpt_bot.generate_summary
    end
  end

  def publish_tweets
    safe_execute("Étape 3: Publication des tweets") do
      publisher = TwitterPublisher.new
      publisher.publish_tweets
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  runner = BotRunner.new
  runner.run
end