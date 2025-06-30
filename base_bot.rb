require 'dotenv'
require 'logger'
require 'fileutils'
require_relative 'config'
require_relative 'health_monitor'
require_relative 'backup_manager'
require_relative 'enhanced_monitoring'

Dotenv.load

class BaseBot
  attr_reader :logger, :health_monitor, :backup_manager, :monitoring

  def initialize
    setup_logging
    TwitterBotConfig.validate!
    @health_monitor = HealthMonitor.new
    @backup_manager = BackupManager.new
    @monitoring = EnhancedMonitoring.new(alerts_enabled: ENV['ENABLE_ALERTS'] == 'true')
  end

  protected

  def validate_env_vars(*vars)
    missing = vars.select { |var| ENV[var].to_s.strip.empty? }
    raise "Variables d'environnement manquantes: #{missing.join(', ')}" unless missing.empty?
  end

  def safe_execute(description, &block)
    start_time = Time.now
    logger.info("Début: #{description}")
    
    result = yield
    duration = Time.now - start_time
    
    logger.info("Succès: #{description} (#{duration.round(2)}s)")
    @health_monitor.record_operation(description, :success, duration)
    @monitoring.record_event('operation', {
      description: description,
      success: true,
      duration: duration
    })
    result
  rescue StandardError => e
    duration = Time.now - start_time
    logger.error("Échec: #{description} - #{e.message}")
    logger.debug(e.backtrace.join("\n"))
    @health_monitor.record_operation(description, :failure, duration, { error: e.message })
    @monitoring.record_event('operation', {
      description: description,
      success: false,
      duration: duration,
      error: e.message
    })
    raise
  end

  def retry_with_backoff(description, max_attempts: nil, &block)
    max_attempts ||= TwitterBotConfig::RETRY_CONFIG[:max_attempts]
    attempt = 1
    
    begin
      logger.info("#{description} (tentative #{attempt}/#{max_attempts})")
      result = yield
      logger.info("Succès: #{description}") if attempt > 1
      result
    rescue *TwitterBotConfig::RETRY_CONFIG[:exceptions] => e
      if attempt < max_attempts
        wait_time = TwitterBotConfig::DELAYS[:retry_wait] * (TwitterBotConfig::RETRY_CONFIG[:backoff_factor] ** (attempt - 1))
        logger.warn("Échec tentative #{attempt}: #{e.message}. Retry dans #{wait_time}s...")
        sleep(wait_time)
        attempt += 1
        retry
      else
        logger.error("Échec définitif après #{max_attempts} tentatives: #{e.message}")
        raise
      end
    end
  end

  def backup_file(file_path)
    return unless File.exist?(file_path)
    
    backup_path = @backup_manager.backup_file(file_path)
    logger.info("Sauvegarde créée: #{backup_path}")
    backup_path
  end

  private

  def setup_logging
    log_file = TwitterBotConfig::FILES[:logs]
    @logger = Logger.new(MultiIO.new(STDOUT, File.open(log_file, 'a')))
    @logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
    end
  end
end

class MultiIO
  def initialize(*targets)
    @targets = targets
  end

  def write(*args)
    @targets.each { |t| t.write(*args) }
  end

  def close
    @targets.each(&:close)
  end
end