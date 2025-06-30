#!/usr/bin/env ruby

require_relative 'config'
require_relative 'base_bot'
require_relative 'twitter_scraper'
require_relative 'bot_chatgpt'
require_relative 'bot_publish'
require 'fileutils'

class AutoBotOrchestrator < BaseBot
  def initialize
    super
    @start_time = Time.now
  end

  def run_complete_workflow
    logger.info("🚀 Démarrage du workflow automatique complet à #{@start_time}")
    
    begin
      # Valider la configuration
      TwitterBotConfig.validate!
      
      # Étape 1: Scraping des données
      scrape_step
      
      # Étape 2: Génération des tweets via GPT
      generate_tweets_step
      
      # Étape 3: Publication des tweets
      publish_tweets_step
      
      # Étape 4: Nettoyage et archivage
      cleanup_step
      
      logger.info("✅ Workflow complet terminé avec succès en #{elapsed_time} secondes")
      
    rescue StandardError => e
      logger.error("❌ Erreur dans le workflow: #{e.message}")
      logger.error(e.backtrace.join("\n"))
      raise
    end
  end

  def run_continuous_mode(interval_hours: 6)
    logger.info("🔄 Mode continu activé - Exécution toutes les #{interval_hours} heures")
    
    loop do
      begin
        run_complete_workflow
        
        next_run = Time.now + (interval_hours * 3600)
        logger.info("⏰ Prochaine exécution prévue à #{next_run}")
        
        # Attendre avec des logs périodiques
        sleep_with_heartbeat(interval_hours * 3600)
        
      rescue StandardError => e
        logger.error("Erreur dans le mode continu: #{e.message}")
        logger.info("Reprise dans 30 minutes...")
        sleep(1800) # 30 minutes
      end
    end
  end

  private

  def scrape_step
    logger.info("📊 Étape 1/4: Scraping des données...")
    
    backup_existing_data
    
    scraper = TwitterScraper.new
    scraper.scrape_all_sources
    
    validate_scraped_data
    logger.info("✅ Scraping terminé avec succès")
  end

  def generate_tweets_step
    logger.info("🤖 Étape 2/4: Génération des tweets via ChatGPT...")
    
    bot = ChatGPTBot.new
    bot.generate_tweets
    
    validate_generated_tweets
    logger.info("✅ Génération des tweets terminée")
  end

  def publish_tweets_step
    logger.info("📱 Étape 3/4: Publication des tweets...")
    
    publisher = TwitterPublisher.new
    publisher.publish_tweets
    
    logger.info("✅ Publication terminée")
  end

  def cleanup_step
    logger.info("🧹 Étape 4/4: Nettoyage et archivage...")
    
    # Créer un dossier d'archive avec timestamp
    archive_dir = File.join(TwitterBotConfig::FILES[:backup_dir], 
                           "archive_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
    FileUtils.mkdir_p(archive_dir)
    
    # Archiver les fichiers
    files_to_archive = [
      TwitterBotConfig::FILES[:tweets_raw],
      TwitterBotConfig::FILES[:tweets_final],
      TwitterBotConfig::FILES[:last_index]
    ]
    
    files_to_archive.each do |file|
      if File.exist?(file)
        FileUtils.cp(file, archive_dir)
        logger.info("Archivé: #{file}")
      end
    end
    
    # Réinitialiser l'index de publication pour le prochain cycle
    File.delete(TwitterBotConfig::FILES[:last_index]) if File.exist?(TwitterBotConfig::FILES[:last_index])
    
    logger.info("✅ Nettoyage terminé")
  end

  def backup_existing_data
    if File.exist?(TwitterBotConfig::FILES[:tweets_raw])
      backup_file(TwitterBotConfig::FILES[:tweets_raw])
    end
  end

  def validate_scraped_data
    unless File.exist?(TwitterBotConfig::FILES[:tweets_raw])
      raise "Fichier de données scrapées non trouvé"
    end
    
    lines = File.readlines(TwitterBotConfig::FILES[:tweets_raw])
    if lines.size < 2  # Au moins l'en-tête et une ligne de données
      raise "Aucune donnée scrapée trouvée"
    end
    
    logger.info("#{lines.size - 1} éléments scrapés validés")
  end

  def validate_generated_tweets
    unless File.exist?(TwitterBotConfig::FILES[:tweets_final])
      raise "Fichier de tweets générés non trouvé"
    end
    
    content = File.read(TwitterBotConfig::FILES[:tweets_final])
    tweet_count = content.scan(/^[•\-]\s*.+/).size
    
    if tweet_count == 0
      raise "Aucun tweet généré trouvé"
    elsif tweet_count != 7
      logger.warn("Attention: #{tweet_count} tweets générés au lieu de 7")
    end
    
    logger.info("#{tweet_count} tweets validés")
  end

  def elapsed_time
    (Time.now - @start_time).to_i
  end

  def sleep_with_heartbeat(seconds, heartbeat_interval: 300)
    intervals = (seconds / heartbeat_interval).to_i
    remaining = seconds % heartbeat_interval
    
    intervals.times do |i|
      sleep(heartbeat_interval)
      logger.info("💓 Heartbeat #{i + 1}/#{intervals} - Bot actif")
    end
    
    sleep(remaining) if remaining > 0
  end
end

# Script principal
if __FILE__ == $PROGRAM_NAME
  orchestrator = AutoBotOrchestrator.new
  
  # Vérifier les arguments de ligne de commande
  if ARGV.include?('--continuous')
    # Mode continu
    interval = ARGV.include?('--interval') ? ARGV[ARGV.index('--interval') + 1].to_i : 6
    orchestrator.run_continuous_mode(interval_hours: interval)
  else
    # Exécution unique
    orchestrator.run_complete_workflow
  end
end