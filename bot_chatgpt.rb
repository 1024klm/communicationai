require 'httparty'
require 'json'
require 'csv'
require_relative 'base_bot'
require_relative 'config'
require_relative 'rate_limiter'

class ChatGPTBot < BaseBot
  def initialize
    super
    validate_env_vars('OPENAI_API_KEY')
    @api_key = ENV['OPENAI_API_KEY']
    @rate_limiter = RateLimiter.new(max_requests_per_hour: 20, storage_file: 'openai_rate_limit.json')
  end

  def generate_summary
    safe_execute("Génération du résumé ChatGPT") do
      backup_file(TwitterBotConfig::FILES[:tweets_raw])
      
      tweets_content = read_tweets_file
      raise "Aucun tweet trouvé" if tweets_content.strip.empty?

      @rate_limiter.rate_limit_if_needed
      response = retry_with_backoff("Requête API OpenAI") { make_api_request(tweets_content, :crypto_news) }
      process_response(response)
    end
  end

  def generate_tweets
    safe_execute("Génération des 7 tweets via ChatGPT") do
      scraped_content = read_scraped_data
      raise "Aucun contenu scraped trouvé" if scraped_content.strip.empty?

      @rate_limiter.rate_limit_if_needed
      response = retry_with_backoff("Requête API OpenAI pour tweets") { make_api_request("Contenu à analyser:\n" + scraped_content, :generate_tweets, 0.8) }
      process_tweet_response(response)
    end
  end

  private

  def read_tweets_file
    File.read(TwitterBotConfig::FILES[:tweets_raw])
  rescue Errno::ENOENT
    raise "Fichier des tweets non trouvé: #{TwitterBotConfig::FILES[:tweets_raw]}"
  end

  def make_api_request(content, prompt_type, temperature = 0.7)
    prompt = TwitterBotConfig::CHATGPT_PROMPTS[prompt_type] + "\n\n" + content

    HTTParty.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{@api_key}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-4",
        messages: [{ role: "user", content: prompt }],
        max_tokens: 2000,
        temperature: temperature
      }.to_json,
      timeout: 120
    )
  end

  def process_response(response)
    validate_api_response(response)
    content = extract_response_content(response)
    save_content(content)
    logger.info("Résumé généré et sauvegardé avec succès")
  end

  def save_content(content)
    File.write(TwitterBotConfig::FILES[:tweets_final], content)
  end

  def read_scraped_data
    return "" unless File.exist?(TwitterBotConfig::FILES[:tweets_raw])
    
    content = []
    CSV.foreach(TwitterBotConfig::FILES[:tweets_raw], headers: true) do |row|
      content << "#{row['source']}: #{row['text']}" if row['text']&.strip
    end
    content.join("\n")
  rescue => e
    raise "Erreur lecture données scrapées: #{e.message}"
  end

  def process_tweet_response(response)
    validate_api_response(response)
    content = extract_response_content(response)
    save_content(content)
    logger.info("7 tweets générés et sauvegardés avec succès")
  end

  def validate_api_response(response)
    raise "Erreur API OpenAI: #{response.code} - #{response.message}" unless response.success?
  end

  def extract_response_content(response)
    content = response.dig("choices", 0, "message", "content")
    raise "Réponse vide de l'API" if content.to_s.strip.empty?
    content
  end
end

if __FILE__ == $PROGRAM_NAME
  bot = ChatGPTBot.new
  bot.generate_summary
end
