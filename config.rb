module TwitterBotConfig
  # Comptes Twitter à surveiller
  ACCOUNTS_TO_MONITOR = %w[
    coinacademy_fr 
    LeJournalDuCoin 
    Paul_Theway 
    wallstreetbets 
    crypto_Futur 
    GoodValueCrypto 
    DeepWhale_ 
    Crypto__Goku 
    CryptoPicsou 
    XFenaux 
    CFarmeur 
    FranceCryptos 
    captaincrypto21 
    CryptoastMedia 
    MoneyRadar_fr 
    PowerHasheur
  ].freeze

  # Configuration des délais
  DELAYS = {
    scroll_wait: 2,
    retry_wait: 3
  }.freeze

  # Configuration des timeouts
  TIMEOUTS = {
    default: 30,
    api_request: 120
  }.freeze

  # Configuration des fichiers
  FILES = {
    tweets_raw: 'tweets_du_jour.csv',
    tweets_final: 'tweets_final.csv',
    last_index: 'last_published_index.txt',
    logs: 'bot_logs.log',
    backup_dir: 'backups'
  }.freeze

  # Configuration des retry
  RETRY_CONFIG = {
    max_attempts: 3,
    backoff_factor: 2,
    exceptions: [StandardError, Selenium::WebDriver::Error::WebDriverError]
  }.freeze

  # Validation de la configuration
  def self.validate!
    raise "ACCOUNTS_TO_MONITOR ne peut pas être vide" if ACCOUNTS_TO_MONITOR.empty?
    
    required_env_vars = %w[TWITTER_USERNAME TWITTER_PASSWORD OPENAI_API_KEY]
    missing_vars = required_env_vars.select { |var| ENV[var].to_s.strip.empty? }
    raise "Variables d'environnement manquantes: #{missing_vars.join(', ')}" unless missing_vars.empty?
    
    # Créer les dossiers nécessaires
    Dir.mkdir(FILES[:backup_dir]) unless Dir.exist?(FILES[:backup_dir])
  end

  # Configuration des prompts ChatGPT
  CHATGPT_PROMPTS = {
    crypto_news: <<~PROMPT
      **Tâche : Résumer les dernières nouvelles crypto à partir d'un ensemble de tweets**

      **Contexte :** Vous avez accès à un fichier CSV contenant des tweets récents sur les cryptomonnaies. Votre tâche est de créer un résumé concis et informatif des principales nouvelles et tendances du monde des cryptomonnaies.

      **Instructions :**
      1. Analysez le contenu des tweets fournis dans le fichier CSV.
      2. Identifiez les sujets et tendances clés mentionnés dans ces tweets.
      3. Créez un résumé sous forme de liste à puces (bullet points) des nouvelles les plus importantes et pertinentes.
      4. Limitez-vous à 5-7 points principaux.
      5. Chaque point doit être concis, ne dépassant pas 280 caractères (la limite d'un tweet).
      6. Concentrez-vous sur les faits et évitez les opinions personnelles.
      7. Si possible, incluez des données chiffrées pertinentes (par exemple, variations de prix, volumes d'échanges).
      8. Excluez toute mention de concours, giveaways, promotions, ainsi que les noms de médias ou de comptes sur les réseaux sociaux.
      9. Pour chaque nouvelle, ajoutez la date la plus récente liée à cette information et, si possible, un lien vers l'article ou la source pertinente pour fournir du contexte.
      10. Utilisez un langage clair et accessible, évitez le jargon technique excessif.

      **Format de sortie :**
      • [Nouvelle crypto 1] - [Date] [Lien vers article pertinent]  
      • [Nouvelle crypto 2] - [Date] [Lien vers article pertinent]  
      • [Nouvelle crypto 3] - [Date] [Lien vers article pertinent]  
      • [Nouvelle crypto 4] - [Date] [Lien vers article pertinent]  
      • [Nouvelle crypto 5] - [Date] [Lien vers article pertinent]  
    PROMPT,
    
    generate_tweets: <<~PROMPT
      **Tâche : Créer exactement 7 tweets sur les actualités crypto**

      **Contexte :** Vous avez accès à des informations récentes sur les cryptomonnaies provenant de Twitter et d'articles de presse. Votre tâche est de créer exactement 7 tweets engageants et informatifs.

      **Instructions strictes :**
      1. Créez EXACTEMENT 7 tweets, ni plus ni moins
      2. Chaque tweet doit contenir au maximum 280 caractères
      3. Les tweets doivent être variés : actualités, analyses, tendances, conseils
      4. Utilisez un ton professionnel mais accessible
      5. Incluez des emojis pertinents (🚀 📈 💎 🔥 ⚡ 🌟 💰) avec modération
      6. N'incluez PAS de hashtags (ils seront ajoutés automatiquement)
      7. N'incluez PAS de liens (ils seront ajoutés si nécessaire)
      8. Évitez les mentions de comptes spécifiques
      9. Concentrez-vous sur les faits et les tendances importantes
      10. Assurez-vous que chaque tweet apporte une valeur unique

      **Types de tweets à inclure :**
      - 2-3 tweets sur les dernières actualités importantes
      - 1-2 tweets d'analyse de marché ou de tendances
      - 1-2 tweets éducatifs ou de conseils
      - 1 tweet de synthèse ou de perspective

      **Format de sortie EXACT :**
      • [Tweet 1 - max 280 caractères]
      • [Tweet 2 - max 280 caractères]
      • [Tweet 3 - max 280 caractères]
      • [Tweet 4 - max 280 caractères]
      • [Tweet 5 - max 280 caractères]
      • [Tweet 6 - max 280 caractères]
      • [Tweet 7 - max 280 caractères]
    PROMPT
  }.freeze
end 