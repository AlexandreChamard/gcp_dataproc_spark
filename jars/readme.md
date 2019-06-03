
# Informations

Ces ressources ont été trouvé sur les sites mvnrepository.com et java2s.com.
Ils sont utilisé dans ce projet pour les raisons suivantes:
- pouvoir parser du json avec serde dans Hive.
- pouvoir parser du xml avec serde dans Hive.

# Utilisation

Mettre les jars dans un même dossier (ex: 'gs://bucket/location/jars') dans Google Storage.
Ces jars sont utilisés par le binaire init_dataproc_node.sh pour ajouter des fonctionalités à serde.
La variable metadata **jar-modules** doit contenir la localisation des différents jars.

rajouter dans votre commande *cluster create*:
    --metadata='jar-modules=gs://bucket/location/jars/*.jar'
    --initialization-actions "gs://bucket/location/init_dataproc_node.sh"
