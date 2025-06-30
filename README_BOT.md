# Bot Twitter Crypto Automatique

Bot automatisé pour scraper, générer et publier des tweets sur les actualités crypto.

## Fonctionnalités

1. **Scraping automatique** : Collecte les informations depuis :
   - Comptes Twitter crypto influents
   - Sites d'actualités crypto (Cryptoast, Journal du Coin, Cointelegraph)

2. **Génération intelligente** : Utilise GPT-4 pour créer exactement 7 tweets engageants

3. **Publication automatique** : Publie les tweets avec des délais anti-détection

4. **Monitoring avancé** : Système de logs et métriques détaillées

## Installation

1. Installer les dépendances Ruby :
```bash
bundle install
```

2. Configurer les variables d'environnement dans `.env` :
```
TWITTER_USERNAME=votre_username
TWITTER_PASSWORD=votre_password
OPENAI_API_KEY=votre_cle_api_openai
ENABLE_ALERTS=true  # Optionnel
DEBUG=false         # Optionnel
```

## Utilisation

### Exécution unique
```bash
ruby auto_bot_orchestrator.rb
```

### Mode continu (exécution toutes les 6 heures)
```bash
ruby auto_bot_orchestrator.rb --continuous
```

### Mode continu avec intervalle personnalisé (en heures)
```bash
ruby auto_bot_orchestrator.rb --continuous --interval 4
```

### Debug mode (affiche le navigateur)
```bash
DEBUG=true ruby auto_bot_orchestrator.rb
```

## Architecture

- `auto_bot_orchestrator.rb` : Orchestrateur principal
- `twitter_scraper.rb` : Module de scraping
- `bot_chatgpt.rb` : Génération des tweets via GPT
- `bot_publish.rb` : Publication sur Twitter
- `enhanced_monitoring.rb` : Système de monitoring
- `config.rb` : Configuration centralisée

## Workflow automatique

1. **Scraping** (10-15 min)
   - Collecte ~10 tweets par compte surveillé
   - Scrape les articles récents des sites crypto

2. **Génération** (1-2 min)
   - Analyse du contenu par GPT-4
   - Création de 7 tweets optimisés

3. **Publication** (15-20 min)
   - Connexion sécurisée à Twitter
   - Publication avec délais progressifs (30s à 3min entre tweets)
   - Comportement humain simulé

4. **Archivage**
   - Sauvegarde des données dans `backups/`
   - Réinitialisation pour le prochain cycle

## Sécurité et anti-détection

- User agents aléatoires
- Délais variables entre actions
- Simulation de comportement humain (frappe, mouvements souris)
- Mode headless avec Chrome/Chromium
- Rotation des patterns d'utilisation

## Monitoring

Les métriques sont sauvegardées dans `bot_metrics.json` :
- Taux de succès des opérations
- Temps de réponse moyens
- Historique des publications
- Alertes en cas d'erreurs

Pour générer un rapport :
```bash
ruby -r ./enhanced_monitoring.rb -e "puts EnhancedMonitoring.new.generate_report"
```

## Logs

- `bot_logs.log` : Logs détaillés de toutes les opérations
- `bot_alerts.log` : Alertes et erreurs critiques
- `bot_metrics.json` : Métriques de performance

## Dépannage

1. **Erreur de connexion Twitter** : Vérifier les identifiants dans `.env`
2. **Erreur API OpenAI** : Vérifier la clé API et les quotas
3. **Timeout scraping** : Augmenter les timeouts dans `config.rb`
4. **Chrome non trouvé** : Installer Chrome ou utiliser le binaire fourni

## Notes importantes

- Ne pas exécuter plusieurs instances simultanément
- Respecter les limites de taux Twitter (max 300 tweets/3h)
- Surveiller régulièrement les logs pour détecter les blocages
- Adapter les délais si nécessaire pour éviter la détection