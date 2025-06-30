# Bot Twitter Crypto - Version Optimisée

Bot automatisé pour la collecte, l'analyse et la publication de nouvelles crypto depuis Twitter.

## 🚀 Fonctionnalités

- **Scraping intelligent** : Collecte des tweets depuis des comptes crypto sélectionnés
- **Analyse IA** : Résumés automatiques via ChatGPT-4
- **Publication automatique** : Diffusion des résumés sur Twitter
- **Monitoring avancé** : Suivi de santé et métriques de performance
- **Anti-détection** : Comportement humain simulé pour éviter les blocages
- **Rate limiting** : Respect des limites API
- **Sauvegardes automatiques** : Protection des données
- **Retry intelligent** : Gestion robuste des erreurs

## 📁 Architecture

```
communicationai/
├── base_bot.rb           # Classe de base avec fonctionnalités communes
├── twitter_bot.rb        # Gestion Selenium et interactions Twitter
├── bot_webdriver.rb      # Scraping des tweets
├── bot_chatgpt.rb        # Génération de résumés IA
├── bot_publish.rb        # Publication des tweets
├── run_bot.rb            # Orchestrateur principal
├── config.rb             # Configuration centralisée
├── health_monitor.rb     # Monitoring de santé
├── rate_limiter.rb       # Gestion des limites API
├── backup_manager.rb     # Gestion des sauvegardes
└── status.rb             # Affichage du statut système
```

## ⚙️ Installation

1. **Prérequis**
```bash
# Ruby 3.0+
gem install bundler
bundle install

# Chrome/Chromium
sudo apt-get install google-chrome-stable
```

2. **Configuration**
```bash
cp .env.example .env
# Éditer .env avec vos clés API
```

3. **Variables d'environnement**
```env
OPENAI_API_KEY=your_openai_api_key
TWITTER_USERNAME=your_twitter_username
TWITTER_PASSWORD=your_twitter_password
TWITTER_EMAIL=your_twitter_email
DEBUG=false  # true pour mode visible
```

## 🎯 Utilisation

### Exécution complète
```bash
ruby run_bot.rb
```

### Modules individuels
```bash
# Scraping uniquement
ruby bot_webdriver.rb

# Génération résumés uniquement
ruby bot_chatgpt.rb

# Publication uniquement
ruby bot_publish.rb
```

### Monitoring
```bash
# Statut complet
ruby status.rb

# Santé uniquement
ruby status.rb health

# Sauvegardes uniquement
ruby status.rb backups

# Nettoyage
ruby status.rb cleanup
```

## 🛡️ Sécurité & Performance

### Anti-détection
- User-Agent réaliste
- Délais aléatoires entre actions
- Simulation de mouvements de souris
- Frappe humaine simulée
- Mode headless optimisé

### Rate Limiting
- Limite OpenAI : 20 requêtes/heure
- Délais adaptatifs entre opérations
- Gestion automatique des quotas

### Monitoring
- Logs détaillés avec timestamps
- Métriques de performance
- Suivi des taux d'erreur
- Alertes de santé système

## 📊 Fichiers générés

- `tweets_du_jour.csv` : Tweets collectés
- `tweets_final.csv` : Résumés générés
- `last_published_index.txt` : Index de publication
- `bot_logs.log` : Logs détaillés
- `health_check.json` : Métriques de santé
- `backups/` : Sauvegardes automatiques

## 🔧 Configuration avancée

### Comptes surveillés
Modifier `ACCOUNTS_TO_MONITOR` dans `config.rb`

### Délais et timeouts
Ajuster `DELAYS` et `TIMEOUTS` dans `config.rb`

### Prompts ChatGPT
Personnaliser `CHATGPT_PROMPTS` dans `config.rb`

## 🐛 Dépannage

### Erreurs courantes
```bash
# Vérifier les logs
tail -f bot_logs.log

# Statut système
ruby status.rb health

# Variables d'environnement
ruby -e "require 'dotenv'; Dotenv.load; puts ENV['OPENAI_API_KEY'] ? 'OK' : 'MISSING'"
```

### Mode debug
```bash
export DEBUG=true
ruby run_bot.rb
```

## 📈 Optimisations

- **Performance** : Chrome headless, images désactivées
- **Mémoire** : Nettoyage automatique des anciennes données
- **Réseau** : Retry avec backoff exponentiel
- **Stockage** : Compression des sauvegardes

## 🔄 Automatisation

### Cron (exécution quotidienne)
```bash
# Ajouter à crontab -e
0 8 * * * cd /path/to/communicationai && ruby run_bot.rb
```

### Systemd (service permanent)
```ini
[Unit]
Description=Bot Twitter Crypto
After=network.target

[Service]
Type=simple
User=your_user
WorkingDirectory=/path/to/communicationai
ExecStart=/usr/bin/ruby run_bot.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

## 📞 Support

Pour signaler des bugs ou demander des fonctionnalités, créer une issue dans le repository.