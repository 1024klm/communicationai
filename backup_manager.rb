require 'fileutils'
require 'json'
require 'zlib'

class BackupManager
  def initialize(backup_dir: 'backups')
    @backup_dir = backup_dir
    ensure_backup_directory
  end

  def backup_file(file_path, compress: true)
    return unless File.exist?(file_path)
    
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = File.basename(file_path)
    backup_filename = "#{File.basename(filename, '.*')}_#{timestamp}#{File.extname(filename)}"
    backup_path = File.join(@backup_dir, backup_filename)
    
    if compress && should_compress?(file_path)
      backup_path += '.gz'
      compress_file(file_path, backup_path)
    else
      FileUtils.cp(file_path, backup_path)
    end
    
    cleanup_old_backups(filename)
    backup_path
  end

  def restore_file(backup_path, restore_path)
    raise "Fichier de sauvegarde introuvable: #{backup_path}" unless File.exist?(backup_path)
    
    if backup_path.end_with?('.gz')
      decompress_file(backup_path, restore_path)
    else
      FileUtils.cp(backup_path, restore_path)
    end
    
    puts "Fichier restauré: #{restore_path}"
  end

  def list_backups(pattern: nil)
    backups = Dir.glob(File.join(@backup_dir, '*')).map do |path|
      {
        path: path,
        filename: File.basename(path),
        size: File.size(path),
        created_at: File.mtime(path)
      }
    end
    
    if pattern
      backups.select! { |backup| backup[:filename].include?(pattern) }
    end
    
    backups.sort_by { |backup| backup[:created_at] }.reverse
  end

  def get_backup_stats
    backups = list_backups
    total_size = backups.sum { |backup| backup[:size] }
    
    {
      total_backups: backups.size,
      total_size_mb: (total_size / 1024.0 / 1024.0).round(2),
      oldest_backup: backups.last&.dig(:created_at),
      newest_backup: backups.first&.dig(:created_at)
    }
  end

  def cleanup_old_backups(filename_pattern, keep_count: 5)
    matching_backups = list_backups(pattern: filename_pattern)
    
    if matching_backups.size > keep_count
      old_backups = matching_backups[keep_count..-1]
      old_backups.each do |backup|
        File.delete(backup[:path])
        puts "Ancienne sauvegarde supprimée: #{backup[:filename]}"
      end
    end
  end

  def create_full_backup
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    backup_name = "full_backup_#{timestamp}.json"
    backup_path = File.join(@backup_dir, backup_name)
    
    backup_data = {
      timestamp: Time.now.iso8601,
      files: {}
    }
    
    important_files = [
      TwitterBotConfig::FILES[:tweets_raw],
      TwitterBotConfig::FILES[:tweets_final],
      TwitterBotConfig::FILES[:last_index],
      'health_check.json',
      'openai_rate_limit.json',
      'rate_limit.json'
    ]
    
    important_files.each do |file|
      next unless File.exist?(file)
      
      backup_data[:files][file] = {
        content: File.read(file),
        size: File.size(file),
        modified_at: File.mtime(file).iso8601
      }
    end
    
    File.write(backup_path, JSON.pretty_generate(backup_data))
    puts "Sauvegarde complète créée: #{backup_path}"
    backup_path
  end

  private

  def ensure_backup_directory
    FileUtils.mkdir_p(@backup_dir) unless Dir.exist?(@backup_dir)
  end

  def should_compress?(file_path)
    File.size(file_path) > 1024 # Compresser si > 1KB
  end

  def compress_file(source_path, dest_path)
    Zlib::GzipWriter.open(dest_path) do |gz|
      gz.write(File.read(source_path))
    end
  end

  def decompress_file(source_path, dest_path)
    Zlib::GzipReader.open(source_path) do |gz|
      File.write(dest_path, gz.read)
    end
  end
end