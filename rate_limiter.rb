require 'json'
require 'time'

class RateLimiter
  def initialize(max_requests_per_hour: 50, storage_file: 'rate_limit.json')
    @max_requests_per_hour = max_requests_per_hour
    @storage_file = storage_file
    @requests = load_requests
  end

  def can_make_request?
    cleanup_old_requests
    @requests.size < @max_requests_per_hour
  end

  def record_request
    cleanup_old_requests
    @requests << Time.now.to_i
    save_requests
  end

  def wait_time_until_next_request
    return 0 if can_make_request?
    
    oldest_request = @requests.min
    one_hour_later = oldest_request + 3600
    [one_hour_later - Time.now.to_i, 0].max
  end

  def rate_limit_if_needed
    unless can_make_request?
      wait_time = wait_time_until_next_request
      if wait_time > 0
        puts "Rate limit atteint. Attente de #{wait_time} secondes..."
        sleep(wait_time)
      end
    end
    record_request
  end

  private

  def cleanup_old_requests
    one_hour_ago = Time.now.to_i - 3600
    @requests.reject! { |timestamp| timestamp < one_hour_ago }
  end

  def load_requests
    return [] unless File.exist?(@storage_file)
    
    JSON.parse(File.read(@storage_file))
  rescue JSON::ParserError
    []
  end

  def save_requests
    File.write(@storage_file, @requests.to_json)
  end
end