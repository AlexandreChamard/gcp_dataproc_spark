#!/bin/bash

readonly region="europe-west3"
readonly zone="${region}-c"

readonly sql_instance_name="hive-metastore"
readonly cluster_name="test-cluster"

readonly project=$(gcloud info --format='value(config.project)')
readonly bucket_name="${project}-warehouse"
readonly bucket_location="gs://${bucket_name}"

readonly python_modules="numpy pandas scipy spacy nltk"
readonly jar_modules="${bucket_location}/jars/*.jar"
readonly spacy_modules="fr_core_news_sm"

function parseArguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|-help|--help)
            help=true
            shift
            ;;
            --erase-cluster)
            erase_cluster=true
            erase=true
            shift
            ;;
            --erase-sql)
            erase_sql=true
            erase=true
            shift
            ;;
            --erase-bucket)
            erase_bucket=true
            erase=true
            shift
            ;;
            --install)
            install=true
            shift
            ;;
            *)
            shift
            ;;
        esac
    done
}

function createSomething() {
    # set the default Compute Engine zone to the zone where you are going to create your Cloud Dataproc clusters
    echo "set the default Compute Engine zone to the zone where you are going to create your Cloud Dataproc clusters"
    gcloud config set compute/zone ${zone}

    # create the warehouse bucket
    gsutil ls ${bucket_location} &>/dev/null
    if [[ $? != 0 ]]; then
        echo "create the warehouse bucket"
        gsutil mb -l ${region} ${bucket_location}
    else
        echo "Warehouse bucket ${bucket_location} already exist."
    fi

    if [[ $? != 0 ]]; then
        exit 1
    fi

    # create a new Cloud SQL instance that will later be used to host the Hive metastore
    gcloud sql instances describe ${sql_instance_name} &>/dev/null
    if [[ $? != 0 ]]; then
        # Enable the Cloud Dataproc and Cloud SQL Admin APIs
        echo "Enable the Cloud Dataproc and Cloud SQL Admin APIs"
        gcloud services enable dataproc.googleapis.com sqladmin.googleapis.com


        echo "Creating Cloud SQL instance named ${sql_instance_name}"
        gcloud sql instances create ${sql_instance_name} \
            --database-version MYSQL_5_7 \
            --storage-type HDD \
            --zone=${zone} \
            --activation-policy ALWAYS
    else
        echo "SQL instance ${sql_instance_name} already create."
    fi

    if [[ $? != 0 ]]; then
        exit 1
    fi

    # Create the first Cloud Dataproc cluster
    gcloud beta dataproc clusters describe ${cluster_name} &>/dev/null
    if [[ $? != 0 ]]; then
        echo "Create a Cloud Dataproc cluster named ${cluster_name}"
        gcloud beta dataproc clusters create ${cluster_name} \
            --image-version 1.4 \
            --region ${region} --zone ${zone} \
            --master-machine-type n1-standard-2 --master-boot-disk-size 100GB \
            --num-workers 2 \
            --worker-machine-type n1-standard-2 --worker-boot-disk-size 100GB \
            --scopes sql-admin \
            --initialization-actions "gs://dataproc-initialization-actions/cloud-sql-proxy/cloud-sql-proxy.sh,gs://spark-datasulting-warehouse/utils/init_dataproc_node.sh" \
            --properties "hive:hive.metastore.warehouse.dir=${bucket_location}/datasets" \
            --metadata "hive-metastore-instance=${project}:${region}:${sql_instance_name},python-modules=${python_modules},jar-modules=${jar_modules},spacy-modules=${spacy_modules}" \
            --expiration-time "$(date +%Y-%m-%d)T19"
    else
        echo "dataproc cluster ${cluster_name} already exist."
    fi
}

function eraseSomething() {
    if [[ ${erase_cluster} ]]; then
        read -p "Are you sure to remove the dataproc cluster ${cluster_name}? " -n 1 -r
        echo
        if [[ ${REPLY} =~ ^[Yy]$ ]]; then
            gcloud dataproc clusters delete ${cluster_name} --region ${region} --quiet
        fi
    fi

    if [[ ${erase_sql} ]]; then
        read -p "Are you sure to remove the sql instance ${sql_instance_name}? " -n 1 -r
        echo
        if [[ ${REPLY} =~ ^[Yy]$ ]]; then
            gcloud sql instances delete ${sql_instance_name} --quiet
        fi
    fi

    if [[ ${erase_bucket} ]]; then
        read -p "Are you sure to remove bucket ${bucket_location} ? " -n 1 -r
        echo
        if [[ ${REPLY} =~ ^[Yy]$ ]]; then
            gsutil rm -r ${bucket_location}
        fi
    fi
}

function main() {
    parseArguments $@
    if [[ ${help} ]]; then
        echo "USAGE : $0 [ -h|--help ] [ --erase-cluster ] [ --erase-sql ] [ --erase-bucket ] [ --install ]"
    elif [[ ${erase} ]]; then
        eraseSomething
        if [[ ${install} ]]; then
            createSomething
        fi
    else
        createSomething
    fi
}

main $@