set -m

/entrypoint.sh couchbase-server &

sleep 15

# Setup initial cluster/ Initialize Node
couchbase-cli cluster-init -c 127.0.0.1 --cluster-name $CLUSTER_NAME --cluster-username $COUCHBASE_ADMINISTRATOR_USERNAME  --cluster-password $COUCHBASE_ADMINISTRATOR_PASSWORD --services $COUCHBASE_SERVICES --cluster-ramsize 1024 --cluster-index-ramsize 256 --cluster-fts-ramsize 256 --cluster-eventing-ramsize 256 --cluster-analytics-ramsize 1024 --index-storage-setting memopt

# Setup Administrator username and password
curl -v http://127.0.0.1:8091/settings/web -d port=8091 -d username=$COUCHBASE_ADMINISTRATOR_USERNAME -d password=$COUCHBASE_ADMINISTRATOR_PASSWORD

sleep 15

# Setup RBAC user using CLI
couchbase-cli user-manage -c 127.0.0.1:8091 --username $COUCHBASE_ADMINISTRATOR_USERNAME --password $COUCHBASE_ADMINISTRATOR_PASSWORD --set --rbac-username $COUCHBASE_RBAC_USERNAME --rbac-password $COUCHBASE_RBAC_PASSWORD --rbac-name $COUCHBASE_RBAC_NAME --roles admin,bucket_admin[*] --auth-domain local

# Setup Main Bucket
couchbase-cli bucket-create -c 127.0.0.1:8091 --username $COUCHBASE_ADMINISTRATOR_USERNAME  --password $COUCHBASE_ADMINISTRATOR_PASSWORD  --bucket "${COUCHBASE_BUCKET}" --bucket-type couchbase  --bucket-ramsize 256

fg 1
