# Schema de base de données pour le SaaS Twitter Bot

ActiveRecord::Schema.define(version: 2024_01_01) do
  
  # Table des utilisateurs/clients
  create_table :users do |t|
    t.string :email, null: false
    t.string :password_digest, null: false
    t.string :company_name
    t.string :api_key, null: false
    t.boolean :active, default: true
    t.datetime :trial_ends_at
    t.string :stripe_customer_id
    t.string :time_zone, default: 'UTC'
    t.timestamps
    
    t.index :email, unique: true
    t.index :api_key, unique: true
  end

  # Table des plans tarifaires
  create_table :pricing_plans do |t|
    t.string :name, null: false
    t.string :code, null: false
    t.integer :tweets_per_month
    t.integer :accounts_limit
    t.decimal :price_monthly, precision: 10, scale: 2
    t.decimal :price_yearly, precision: 10, scale: 2
    t.json :features
    t.boolean :active, default: true
    t.timestamps
    
    t.index :code, unique: true
  end

  # Table des abonnements
  create_table :subscriptions do |t|
    t.references :user, foreign_key: true
    t.references :pricing_plan, foreign_key: true
    t.string :status # active, cancelled, past_due, trialing
    t.datetime :current_period_start
    t.datetime :current_period_end
    t.integer :tweets_used_this_period, default: 0
    t.string :stripe_subscription_id
    t.string :billing_cycle # monthly, yearly
    t.timestamps
    
    t.index [:user_id, :status]
  end

  # Table des comptes Twitter connectés
  create_table :twitter_accounts do |t|
    t.references :user, foreign_key: true
    t.string :username, null: false
    t.string :encrypted_password
    t.string :encrypted_password_iv
    t.string :display_name
    t.string :profile_image_url
    t.boolean :active, default: true
    t.datetime :last_authenticated_at
    t.datetime :last_posted_at
    t.json :preferences # topics, tone, hashtags, etc.
    t.timestamps
    
    t.index [:user_id, :username]
  end

  # Table des campagnes de tweets
  create_table :tweet_campaigns do |t|
    t.references :user, foreign_key: true
    t.references :twitter_account, foreign_key: true
    t.string :name
    t.string :status # draft, scheduled, active, paused, completed
    t.json :settings # frequency, topics, sources, etc.
    t.integer :tweets_per_day
    t.time :preferred_posting_times, array: true
    t.date :start_date
    t.date :end_date
    t.integer :total_tweets_generated, default: 0
    t.integer :total_tweets_published, default: 0
    t.timestamps
    
    t.index [:user_id, :status]
  end

  # Table des tweets générés
  create_table :generated_tweets do |t|
    t.references :user, foreign_key: true
    t.references :tweet_campaign, foreign_key: true
    t.references :twitter_account, foreign_key: true
    t.text :content, null: false
    t.string :status # pending, approved, rejected, published, failed
    t.datetime :scheduled_for
    t.datetime :published_at
    t.string :twitter_tweet_id
    t.json :metrics # likes, retweets, impressions
    t.json :source_data # sources used to generate
    t.text :gpt_prompt_used
    t.integer :tokens_used
    t.decimal :generation_cost, precision: 10, scale: 4
    t.timestamps
    
    t.index [:user_id, :status]
    t.index :scheduled_for
  end

  # Table des sources de contenu
  create_table :content_sources do |t|
    t.references :user, foreign_key: true
    t.string :source_type # twitter_account, rss_feed, website
    t.string :identifier # @username, URL, etc.
    t.string :name
    t.boolean :active, default: true
    t.json :scraping_config
    t.datetime :last_scraped_at
    t.timestamps
    
    t.index [:user_id, :source_type]
  end

  # Table des jobs de génération
  create_table :generation_jobs do |t|
    t.references :user, foreign_key: true
    t.references :tweet_campaign, foreign_key: true
    t.string :job_id, null: false
    t.string :status # pending, processing, completed, failed
    t.integer :tweets_requested
    t.integer :tweets_generated
    t.json :parameters
    t.text :error_message
    t.datetime :started_at
    t.datetime :completed_at
    t.timestamps
    
    t.index :job_id, unique: true
    t.index [:user_id, :status]
  end

  # Table de facturation
  create_table :invoices do |t|
    t.references :user, foreign_key: true
    t.references :subscription, foreign_key: true
    t.string :invoice_number, null: false
    t.decimal :amount, precision: 10, scale: 2
    t.string :currency, default: 'USD'
    t.string :status # draft, paid, overdue, cancelled
    t.integer :tweets_count
    t.datetime :period_start
    t.datetime :period_end
    t.string :stripe_invoice_id
    t.string :payment_method
    t.timestamps
    
    t.index :invoice_number, unique: true
    t.index [:user_id, :status]
  end

  # Table d'utilisation pour le tracking
  create_table :usage_records do |t|
    t.references :user, foreign_key: true
    t.string :resource_type # tweet_generation, api_call, scraping
    t.integer :quantity
    t.decimal :cost, precision: 10, scale: 4
    t.json :metadata
    t.date :usage_date
    t.timestamps
    
    t.index [:user_id, :usage_date]
    t.index [:user_id, :resource_type, :usage_date]
  end

  # Table des webhooks
  create_table :webhooks do |t|
    t.references :user, foreign_key: true
    t.string :url, null: false
    t.string :events, array: true # tweet_generated, tweet_published, etc.
    t.string :secret_key
    t.boolean :active, default: true
    t.datetime :last_triggered_at
    t.timestamps
    
    t.index [:user_id, :active]
  end

  # Table des logs d'activité
  create_table :activity_logs do |t|
    t.references :user, foreign_key: true
    t.string :action # login, tweet_generated, settings_changed, etc.
    t.string :resource_type
    t.integer :resource_id
    t.json :changes
    t.string :ip_address
    t.string :user_agent
    t.timestamps
    
    t.index [:user_id, :created_at]
    t.index [:resource_type, :resource_id]
  end

  # Table des API rate limits
  create_table :api_rate_limits do |t|
    t.references :user, foreign_key: true
    t.string :endpoint
    t.integer :requests_count, default: 0
    t.datetime :window_start
    t.timestamps
    
    t.index [:user_id, :endpoint, :window_start]
  end
end