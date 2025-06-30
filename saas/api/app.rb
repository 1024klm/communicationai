require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/activerecord'
require 'jwt'
require 'bcrypt'
require_relative '../models/user'
require_relative '../models/tweet_campaign'
require_relative '../models/generated_tweet'
require_relative '../services/tweet_generator_service'
require_relative '../services/billing_service'
require_relative '../middleware/rate_limiter'
require_relative '../middleware/auth'

class TwitterBotAPI < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  
  configure do
    set :database_file, '../config/database.yml'
    set :show_exceptions, false
    set :raise_errors, false
  end

  configure :development do
    enable :logging
  end

  # Middleware
  use RateLimiter
  use AuthMiddleware

  # Error handling
  error do
    status 500
    json error: "Internal server error", message: env['sinatra.error'].message
  end

  error 404 do
    json error: "Not found"
  end

  # Health check
  get '/health' do
    json status: 'ok', timestamp: Time.now.iso8601
  end

  # Authentication endpoints
  post '/auth/register' do
    begin
      user = User.create!(
        email: params[:email],
        password: params[:password],
        company_name: params[:company_name]
      )
      
      token = generate_jwt(user)
      
      json({
        user: user.as_json(except: [:password_digest]),
        token: token,
        api_key: user.api_key
      })
    rescue ActiveRecord::RecordInvalid => e
      status 422
      json error: "Validation failed", errors: e.record.errors.full_messages
    end
  end

  post '/auth/login' do
    user = User.find_by(email: params[:email])
    
    if user && user.authenticate(params[:password])
      token = generate_jwt(user)
      json({
        user: user.as_json(except: [:password_digest]),
        token: token
      })
    else
      status 401
      json error: "Invalid credentials"
    end
  end

  # Account management
  get '/account' do
    authenticate!
    json current_user.as_json(
      except: [:password_digest],
      include: {
        subscription: {
          include: :pricing_plan
        }
      }
    )
  end

  patch '/account' do
    authenticate!
    if current_user.update(account_params)
      json current_user.as_json(except: [:password_digest])
    else
      status 422
      json error: "Update failed", errors: current_user.errors.full_messages
    end
  end

  # Twitter accounts
  get '/twitter_accounts' do
    authenticate!
    accounts = current_user.twitter_accounts.active
    json accounts
  end

  post '/twitter_accounts' do
    authenticate!
    account = current_user.twitter_accounts.create!(twitter_account_params)
    json account
  rescue ActiveRecord::RecordInvalid => e
    status 422
    json error: "Validation failed", errors: e.record.errors.full_messages
  end

  delete '/twitter_accounts/:id' do
    authenticate!
    account = current_user.twitter_accounts.find(params[:id])
    account.update!(active: false)
    json message: "Account deactivated"
  end

  # Tweet campaigns
  get '/campaigns' do
    authenticate!
    campaigns = current_user.tweet_campaigns.includes(:twitter_account)
    json campaigns.as_json(include: :twitter_account)
  end

  post '/campaigns' do
    authenticate!
    campaign = current_user.tweet_campaigns.create!(campaign_params)
    json campaign
  rescue ActiveRecord::RecordInvalid => e
    status 422
    json error: "Validation failed", errors: e.record.errors.full_messages
  end

  patch '/campaigns/:id' do
    authenticate!
    campaign = current_user.tweet_campaigns.find(params[:id])
    
    if campaign.update(campaign_params)
      json campaign
    else
      status 422
      json error: "Update failed", errors: campaign.errors.full_messages
    end
  end

  # Tweet generation
  post '/tweets/generate' do
    authenticate!
    
    # Check subscription limits
    if !current_user.can_generate_tweets?(params[:count] || 1)
      status 403
      json error: "Tweet limit exceeded", 
           limit: current_user.subscription.tweets_remaining,
           upgrade_url: "/pricing"
    end
    
    # Create generation job
    service = TweetGeneratorService.new(current_user)
    job = service.create_generation_job(
      campaign_id: params[:campaign_id],
      count: params[:count] || 7,
      topics: params[:topics],
      tone: params[:tone]
    )
    
    json job_id: job.job_id, status: 'processing'
  end

  # Get generated tweets
  get '/tweets' do
    authenticate!
    
    tweets = current_user.generated_tweets
                         .includes(:twitter_account, :tweet_campaign)
                         .order(created_at: :desc)
                         .limit(params[:limit] || 50)
    
    json tweets.as_json(include: [:twitter_account, :tweet_campaign])
  end

  # Approve/reject tweets
  patch '/tweets/:id' do
    authenticate!
    tweet = current_user.generated_tweets.find(params[:id])
    
    if ['approved', 'rejected'].include?(params[:status])
      tweet.update!(status: params[:status])
      json tweet
    else
      status 422
      json error: "Invalid status"
    end
  end

  # Schedule tweet
  post '/tweets/:id/schedule' do
    authenticate!
    tweet = current_user.generated_tweets.find(params[:id])
    
    if tweet.status == 'approved'
      tweet.update!(
        scheduled_for: params[:scheduled_for],
        status: 'scheduled'
      )
      json tweet
    else
      status 422
      json error: "Tweet must be approved before scheduling"
    end
  end

  # Usage and billing
  get '/usage' do
    authenticate!
    
    usage = {
      current_period: {
        tweets_used: current_user.subscription.tweets_used_this_period,
        tweets_limit: current_user.subscription.pricing_plan.tweets_per_month,
        period_end: current_user.subscription.current_period_end
      },
      history: current_user.usage_records.where(
        usage_date: 30.days.ago..Date.today
      ).group_by_day(:usage_date).sum(:quantity)
    }
    
    json usage
  end

  get '/invoices' do
    authenticate!
    invoices = current_user.invoices.order(created_at: :desc)
    json invoices
  end

  # Webhooks
  get '/webhooks' do
    authenticate!
    json current_user.webhooks
  end

  post '/webhooks' do
    authenticate!
    webhook = current_user.webhooks.create!(webhook_params)
    json webhook
  rescue ActiveRecord::RecordInvalid => e
    status 422
    json error: "Validation failed", errors: e.record.errors.full_messages
  end

  # Content sources
  get '/sources' do
    authenticate!
    sources = current_user.content_sources.active
    json sources
  end

  post '/sources' do
    authenticate!
    source = current_user.content_sources.create!(source_params)
    json source
  rescue ActiveRecord::RecordInvalid => e
    status 422
    json error: "Validation failed", errors: e.record.errors.full_messages
  end

  private

  def authenticate!
    halt 401, json(error: "Unauthorized") unless current_user
  end

  def current_user
    @current_user ||= begin
      token = request.env['HTTP_AUTHORIZATION']&.split(' ')&.last
      return nil unless token
      
      payload = JWT.decode(token, ENV['JWT_SECRET'], true, algorithm: 'HS256').first
      User.find(payload['user_id'])
    rescue JWT::DecodeError
      nil
    end
  end

  def generate_jwt(user)
    JWT.encode(
      {
        user_id: user.id,
        email: user.email,
        exp: 30.days.from_now.to_i
      },
      ENV['JWT_SECRET'],
      'HS256'
    )
  end

  def account_params
    params.slice(:company_name, :time_zone)
  end

  def twitter_account_params
    params.slice(:username, :password, :preferences)
  end

  def campaign_params
    params.slice(:name, :twitter_account_id, :settings, :tweets_per_day, 
                 :preferred_posting_times, :start_date, :end_date)
  end

  def webhook_params
    params.slice(:url, :events)
  end

  def source_params
    params.slice(:source_type, :identifier, :name, :scraping_config)
  end
end