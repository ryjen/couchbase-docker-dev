#!/usr/bin/env bash

SERVER_IMAGE="ryjen/couchbase"
NODE_IMAGE="couchbase"

SERVER_CONTAINER="cb-server"
SERVER_NODE="cb-node"

GATEWAY_IMAGE="couchbase/sync-gateway:2.0.0-enterprise"
GATEWAY_CONTAINER="sync-gateway"

NETWORK_NAME="cbnetwork"

ADMIN_USERNAME="Administrator"
ADMIN_PASSWORD="password"
BUCKET_NAME="demobucket"

RBAC_USERNAME="admin"
RBAC_PASSWORD="password"

function info() {
  echo $@
  sync
}

function abort_cmd() {
  echo $1
  printf "\033[0;31m"
  read -p "Command failed. Continue? (Y/n)" response
  printf "\033[0m"
  case ${response} in 
    [Nn]*)
      exit $?
      ;;
  esac
}

function exec_cmd() {
  $@

  if [[ $? != 0 ]]; then
    abort_cmd;
  fi
}

function run_cmd() {
  local output=$($@)

  if [[ $? != 0 ]]; then
    abort_cmd $output;
  fi
}

function silence() {
  $@ > /dev/null 2>&1
}

function container_exists() {
  local container=$1

  local exists=$(docker ps -a -q -f name=$container 2>/dev/null)

  if [ -z "$exists" ]; then
    return 1
  fi

  return 0
}

function build_server_image() {

  info "Building server image"

  exec_cmd docker build -t $SERVER_IMAGE server
}

function setup_docker() {

  info "Creating network"

  silence docker network create -d bridge $NETWORK_NAME

  info "Building couchbase server image"

  build_server_image

  info "Pulling sync gateway image"

  exec_cmd docker pull $GATEWAY_IMAGE
}

function start_server() {

  info "Starting couchbase cluster server"

  container_exists $SERVER_CONTAINER

  if [[ $? -eq 0 ]]; then
    run_cmd docker start $SERVER_CONTAINER
    return
  fi

  run_cmd docker run -d --name $SERVER_CONTAINER --network ${NETWORK_NAME} -p "8091-8096:8091-8096" -p 11210-11211:11210-11211 -e COUCHBASE_ADMINISTRATOR_USERNAME=${ADMIN_USERNAME} -e COUCHBASE_ADMINISTRATOR_PASSWORD=${ADMIN_PASSWORD} -e COUCHBASE_BUCKET=${BUCKET_NAME} -e COUCHBASE_RBAC_USERNAME=${RBAC_USERNAME} -e COUCHBASE_RBAC_PASSWORD=${RBAC_PASSWORD} -e COUCHBASE_RBAC_NAME="admin-user" -e CLUSTER_NAME=demo-cluster -e COUCHBASE_SERVICES="data,index,query" $SERVER_IMAGE
}

function add_nodes() {

  info "Starting couchbase server node"

  container_exists $SERVER_NODE

  if [[ $? -eq 0 ]]; then
    run_cmd docker start $SERVER_NODE
    return
  fi

  run_cmd docker run -d --name $SERVER_NODE --network ${NETWORK_NAME} -p :"9091-9096:8091-8096" $NODE_IMAGE

  info "Waiting for node to complete setup"

  sleep 15

  info "Adding node to cluster"

  local NODE_IP=$(docker inspect --format '{{ .NetworkSettings.Networks.cbnetwork.IPAddress }}' $SERVER_NODE)

  run_cmd docker exec $SERVER_CONTAINER couchbase-cli server-add -c ${SERVER_CONTAINER} -u ${RBAC_USERNAME} -p ${RBAC_PASSWORD} --server-add $NODE_IP --server-add-username $RBAC_USERNAME --server-add-password $RBAC_PASSWORD --services fts,eventing,analytics

  sleep 5

  info "Rebalancing cluster"

  run_cmd docker exec $SERVER_CONTAINER couchbase-cli rebalance -c $SERVER_CONTAINER -u $RBAC_USERNAME -p $RBAC_PASSWORD

}

function wait_server() {

  local output=$(docker logs ${SERVER_CONTAINER} 2> /dev/null)

  info "Waiting for cluster to complete setup"

  while [ true ]; do

    case "$output" in
      *couchbase-server*)
        return
        ;;
      *)
        sleep 2
        output=$(docker logs ${SERVER_CONTAINER} 2> /dev/null)
        ;;
    esac
  done
}

function start_docker() {

  start_server

  wait_server

  add_nodes

  info "Starting sync gateway container"

  container_exists $GATEWAY_CONTAINER

  if [[ $? -eq 0 ]]; then
    run_cmd docker start $GATEWAY_CONTAINER
    return
  fi

    run_cmd docker run -p 4984-4985:4984-4985 --network $NETWORK_NAME --name $GATEWAY_CONTAINER -d -v `pwd`/sync_gateway:/etc/sync_gateway $GATEWAY_IMAGE -adminInterface :4985 /etc/sync_gateway/sync_gateway.json
}

function stop_docker() {

  info "Stopping sync gateway container"

  silence docker stop $GATEWAY_CONTAINER

  info "Stopping couchbase server containers"

  silence docker stop $SERVER_CONTAINER

  silence docker stop $SERVER_NODE
}

function clean_docker() {

  stop_docker

  info "Removing sync gateway container"

  silence docker rm $GATEWAY_CONTAINER

  info "Removing couchbase server containers"

  silence docker rm $SERVER_CONTAINER

  silence docker rm $SERVER_NODE
}

function verify_docker() {
  info "Testing sync gateway api\n"
  curl http://localhost:4984
}

case "${1}" in
  setup)
    setup_docker;
    ;;
  start)
    start_docker;
    ;;
  stop)
    stop_docker;
    ;;
  verify)
    verify_docker;
    ;;
  clean)
    clean_docker;
    ;;
  *)
    echo "Syntax: $(basename $0) setup|start|verify|stop|clean"
    exit 1
    ;;
esac

exit $?

