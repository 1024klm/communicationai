#!/usr/bin/env ruby

require_relative 'health_monitor'
require_relative 'backup_manager'

class BotStatus
  def self.show_full_status
    puts "\n" + "=" * 60
    puts "STATUT COMPLET DU BOT TWITTER CRYPTO"
    puts "=" * 60
    
    show_health_status
    show_backup_status
    show_file_status
    
    puts "\n" + "=" * 60
  end

  def self.show_health_status
    puts "\n🏥 SANTÉ DU SYSTÈME"
    puts "-" * 30
    
    health_monitor = HealthMonitor.new
    health_monitor.generate_health_report
  end

  def self.show_backup_status
    puts "\n💾 STATUT DES SAUVEGARDES"
    puts "-" * 30
    
    backup_manager = BackupManager.new
    stats = backup_manager.get_backup_stats
    
    puts "Nombre total de sauvegardes: #{stats[:total_backups]}"
    puts "Taille totale: #{stats[:total_size_mb]} MB"
    puts "Plus ancienne: #{stats[:oldest_backup]}" if stats[:oldest_backup]
    puts "Plus récente: #{stats[:newest_backup]}" if stats[:newest_backup]
    
    puts "\nDernières sauvegardes:"
    backup_manager.list_backups.first(5).each do |backup|
      puts "  #{backup[:filename]} (#{(backup[:size] / 1024.0).round(2)} KB) - #{backup[:created_at]}"
    end
  end

  def self.show_file_status
    puts "\n📁 STATUT DES FICHIERS"
    puts "-" * 30
    
    files_to_check = [
      ['Tweets bruts', TwitterBotConfig::FILES[:tweets_raw]],
      ['Tweets finaux', TwitterBotConfig::FILES[:tweets_final]],
      ['Index de publication', TwitterBotConfig::FILES[:last_index]],
      ['Logs', TwitterBotConfig::FILES[:logs]],
      ['Santé système', 'health_check.json'],
      ['Rate limit OpenAI', 'openai_rate_limit.json'],
      ['Configuration', '.env']
    ]
    
    files_to_check.each do |name, path|
      if File.exist?(path)
        size = File.size(path)
        modified = File.mtime(path)
        puts "  ✅ #{name}: #{(size / 1024.0).round(2)} KB (modifié: #{modified})"
      else
        puts "  ❌ #{name}: Fichier manquant"
      end
    end
  end

  def self.cleanup_old_data
    puts "\n🧹 NETTOYAGE DES ANCIENNES DONNÉES"
    puts "-" * 40
    
    backup_manager = BackupManager.new
    
    # Nettoyer les anciennes sauvegardes pour chaque type de fichier
    ['tweets_du_jour', 'tweets_final', 'last_published_index'].each do |pattern|
      backup_manager.cleanup_old_backups(pattern, keep_count: 10)
    end
    
    puts "Nettoyage terminé!"
  end
end

if __FILE__ == $PROGRAM_NAME
  case ARGV[0]
  when 'health'
    BotStatus.show_health_status
  when 'backups'
    BotStatus.show_backup_status
  when 'files'
    BotStatus.show_file_status
  when 'cleanup'
    BotStatus.cleanup_old_data
  else
    BotStatus.show_full_status
  end
end