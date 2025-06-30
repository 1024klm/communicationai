require 'json'
require 'time'
require 'net/smtp'

class EnhancedMonitoring
  attr_reader :metrics_file, :alerts_enabled

  def initialize(metrics_file: 'bot_metrics.json', alerts_enabled: false)
    @metrics_file = metrics_file
    @alerts_enabled = alerts_enabled
    @metrics = load_metrics
    @alert_thresholds = {
      error_rate: 0.3,        # 30% d'erreurs
      response_time: 120,     # 120 secondes
      consecutive_failures: 3
    }
  end

  def record_event(event_type, details = {})
    timestamp = Time.now.iso8601
    
    event = {
      timestamp: timestamp,
      type: event_type,
      details: details,
      pid: Process.pid
    }
    
    @metrics[:events] ||= []
    @metrics[:events] << event
    
    # Garder seulement les 1000 derniers événements
    @metrics[:events] = @metrics[:events].last(1000)
    
    update_statistics(event_type, details)
    check_alerts(event_type, details)
    save_metrics
  end

  def record_scraping_result(account, tweets_count, duration)
    record_event('scraping', {
      account: account,
      tweets_count: tweets_count,
      duration: duration,
      success: tweets_count > 0
    })
  end

  def record_gpt_request(prompt_type, tokens_used, duration, success)
    record_event('gpt_request', {
      prompt_type: prompt_type,
      tokens_used: tokens_used,
      duration: duration,
      success: success
    })
  end

  def record_tweet_publication(tweet_index, success, error_message = nil)
    record_event('tweet_publication', {
      tweet_index: tweet_index,
      success: success,
      error_message: error_message
    })
  end

  def record_workflow_completion(total_duration, tweets_published)
    record_event('workflow_completion', {
      total_duration: total_duration,
      tweets_published: tweets_published,
      success: tweets_published > 0
    })
  end

  def get_statistics
    {
      total_events: @metrics[:events]&.size || 0,
      last_24h_stats: calculate_period_stats(24),
      last_7d_stats: calculate_period_stats(24 * 7),
      current_error_rate: calculate_error_rate,
      average_response_time: calculate_avg_response_time
    }
  end

  def generate_report
    stats = get_statistics
    
    report = []
    report << "=== Bot Performance Report ==="
    report << "Generated at: #{Time.now}"
    report << ""
    report << "Last 24 Hours:"
    report << "  - Total operations: #{stats[:last_24h_stats][:total_operations]}"
    report << "  - Success rate: #{(stats[:last_24h_stats][:success_rate] * 100).round(1)}%"
    report << "  - Tweets published: #{stats[:last_24h_stats][:tweets_published]}"
    report << ""
    report << "Last 7 Days:"
    report << "  - Total operations: #{stats[:last_7d_stats][:total_operations]}"
    report << "  - Success rate: #{(stats[:last_7d_stats][:success_rate] * 100).round(1)}%"
    report << "  - Tweets published: #{stats[:last_7d_stats][:tweets_published]}"
    report << ""
    report << "Current Status:"
    report << "  - Error rate: #{(stats[:current_error_rate] * 100).round(1)}%"
    report << "  - Avg response time: #{stats[:average_response_time].round(1)}s"
    
    report.join("\n")
  end

  private

  def load_metrics
    return {} unless File.exist?(@metrics_file)
    
    JSON.parse(File.read(@metrics_file), symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  def save_metrics
    File.write(@metrics_file, JSON.pretty_generate(@metrics))
  rescue => e
    puts "Error saving metrics: #{e.message}"
  end

  def update_statistics(event_type, details)
    @metrics[:statistics] ||= {}
    @metrics[:statistics][event_type] ||= {
      total: 0,
      success: 0,
      failure: 0,
      total_duration: 0
    }
    
    stats = @metrics[:statistics][event_type]
    stats[:total] += 1
    
    if details[:success]
      stats[:success] += 1
    else
      stats[:failure] += 1
      @metrics[:consecutive_failures] ||= 0
      @metrics[:consecutive_failures] += 1
    end
    
    if details[:success]
      @metrics[:consecutive_failures] = 0
    end
    
    if details[:duration]
      stats[:total_duration] += details[:duration]
    end
  end

  def check_alerts(event_type, details)
    return unless @alerts_enabled
    
    # Vérifier les échecs consécutifs
    if @metrics[:consecutive_failures] >= @alert_thresholds[:consecutive_failures]
      send_alert("Consecutive Failures", 
                "#{@metrics[:consecutive_failures]} consecutive failures detected")
    end
    
    # Vérifier le taux d'erreur
    error_rate = calculate_error_rate
    if error_rate > @alert_thresholds[:error_rate]
      send_alert("High Error Rate", 
                "Error rate is #{(error_rate * 100).round(1)}%")
    end
    
    # Vérifier le temps de réponse
    if details[:duration] && details[:duration] > @alert_thresholds[:response_time]
      send_alert("Slow Response", 
                "Operation took #{details[:duration].round(1)}s")
    end
  end

  def calculate_period_stats(hours)
    cutoff_time = Time.now - (hours * 3600)
    recent_events = (@metrics[:events] || []).select do |event|
      Time.parse(event[:timestamp]) > cutoff_time rescue false
    end
    
    total = recent_events.size
    success = recent_events.count { |e| e[:details][:success] }
    tweets_published = recent_events.count { |e| e[:type] == 'tweet_publication' && e[:details][:success] }
    
    {
      total_operations: total,
      success_rate: total > 0 ? success.to_f / total : 0,
      tweets_published: tweets_published
    }
  end

  def calculate_error_rate
    recent_events = (@metrics[:events] || []).last(100)
    return 0 if recent_events.empty?
    
    failures = recent_events.count { |e| !e[:details][:success] }
    failures.to_f / recent_events.size
  end

  def calculate_avg_response_time
    recent_events = (@metrics[:events] || []).last(50)
    durations = recent_events.map { |e| e[:details][:duration] }.compact
    
    return 0 if durations.empty?
    durations.sum / durations.size
  end

  def send_alert(subject, message)
    # Log l'alerte
    alert_message = "[ALERT] #{subject}: #{message}"
    puts alert_message
    
    # Ajouter à un fichier d'alertes
    File.open('bot_alerts.log', 'a') do |f|
      f.puts "#{Time.now.iso8601} - #{alert_message}"
    end
    
    # Si configuré, envoyer un email ou une notification
    # TODO: Implémenter l'envoi d'email/webhook si nécessaire
  end
end