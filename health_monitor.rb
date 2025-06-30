require 'json'
require 'time'

class HealthMonitor
  def initialize(log_file: 'health_check.json')
    @log_file = log_file
    @health_data = load_health_data
  end

  def record_operation(operation, status, duration = nil, details = {})
    entry = {
      timestamp: Time.now.iso8601,
      operation: operation,
      status: status,
      duration: duration,
      details: details
    }
    
    @health_data[:operations] ||= []
    @health_data[:operations] << entry
    
    # Garder seulement les 1000 dernières opérations
    @health_data[:operations] = @health_data[:operations].last(1000)
    
    update_statistics(operation, status)
    save_health_data
  end

  def get_health_status
    {
      last_update: Time.now.iso8601,
      statistics: @health_data[:statistics] || {},
      recent_failures: get_recent_failures,
      system_status: calculate_system_status
    }
  end

  def generate_health_report
    status = get_health_status
    
    puts "\n" + "=" * 50
    puts "RAPPORT DE SANTÉ DU BOT"
    puts "=" * 50
    
    puts "\nStatut système: #{status[:system_status]}"
    puts "Dernière mise à jour: #{status[:last_update]}"
    
    puts "\nStatistiques des opérations:"
    status[:statistics].each do |operation, stats|
      success_rate = stats[:success_count].to_f / (stats[:success_count] + stats[:failure_count]) * 100
      puts "  #{operation}: #{success_rate.round(2)}% de succès (#{stats[:success_count]} succès, #{stats[:failure_count]} échecs)"
    end
    
    unless status[:recent_failures].empty?
      puts "\nÉchecs récents (dernières 24h):"
      status[:recent_failures].each do |failure|
        puts "  #{failure[:timestamp]} - #{failure[:operation]}: #{failure[:details]['error'] || 'Erreur inconnue'}"
      end
    end
    
    puts "\n" + "=" * 50
  end

  private

  def load_health_data
    return { operations: [], statistics: {} } unless File.exist?(@log_file)
    
    JSON.parse(File.read(@log_file), symbolize_names: true)
  rescue JSON::ParserError
    { operations: [], statistics: {} }
  end

  def save_health_data
    File.write(@log_file, JSON.pretty_generate(@health_data))
  end

  def update_statistics(operation, status)
    @health_data[:statistics] ||= {}
    @health_data[:statistics][operation] ||= { success_count: 0, failure_count: 0 }
    
    if status == :success
      @health_data[:statistics][operation][:success_count] += 1
    else
      @health_data[:statistics][operation][:failure_count] += 1
    end
  end

  def get_recent_failures(hours_back: 24)
    cutoff_time = Time.now - (hours_back * 3600)
    
    (@health_data[:operations] || []).select do |op|
      Time.parse(op[:timestamp]) > cutoff_time && op[:status] == :failure
    end
  end

  def calculate_system_status
    recent_ops = (@health_data[:operations] || []).last(20)
    return :unknown if recent_ops.empty?
    
    failure_rate = recent_ops.count { |op| op[:status] == :failure }.to_f / recent_ops.size
    
    case failure_rate
    when 0..0.1 then :healthy
    when 0.1..0.3 then :warning
    else :critical
    end
  end
end