
exit

# Ce fichier n'est pas à executer. il rencense des commandes utils pour utiliser dataproc dans Google Cloud Platform.

readonly zone="europe-west3-c"

readonly project=$(gcloud info --format='value(config.project)')

readonly sql_instance_name="hive-metastore"
readonly cluster_name="test-cluster"
readonly master_cluster_name="${cluster_name}-m"

# connexion hive ssh:
gcloud compute ssh ${master_cluster_name} --zone ${zone}
beeline -u "jdbc:hive2://localhost:10000"

# connexion mysql (voir les tables):
gcloud sql connect ${sql_instance_name} --user=root
USE hive_metastore;

# db location: (demande de ce connecter au server sql -voir plus haut-)
SELECT DB_LOCATION_URI FROM DBS;

# reference to metastore: (demande de ce connecter au server sql -voir plus haut-)
SELECT TBL_NAME, TBL_TYPE FROM TBLS;


# ouvrir un tunnel ssh
gcloud compute ssh ${master_cluster_name} --project ${project} --zone ${zone} -- -D 1080 -N

# connection ssh sur un noeud
gcloud compute --project ${project} ssh --zone ${zone} ${master_cluster_name}

# ouvrir hadoop ressource (demande d'avoir déjà créé un tunnel ssh)
/usr/bin/google-chrome --proxy-server="socks5://localhost:1080" --user-data-dir="/tmp/${master_cluster_name}" http://${master_cluster_name}:8088