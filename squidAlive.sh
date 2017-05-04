#!/bin/bash
# ########################################################################
# A program to start a squid docker container if it is stopped, and check
# that it is functioning as expected.
# This check is performed by curling a site from the (unproxied) host
# machine. And runnning the same check from a proxied container
# ########################################################################

. /root/.docker/setenv.sh

#TEST_CONTAINER="jcantosz/curling"
TEST_CONTAINER="ibm_devops_services/worker_base"
TEST_CONTAINER_NAME="squid-nanny"

SQUID_IMAGE="jcantosz/squid-squad"
SQUID_CONTAINER="squid-squad"

# Location of run.sh
RUN_FILE_LOCATION="/root/squidsperiment/run.sh"

# Proxy tester URL
URL="http://ibm.antoszyk.com/file.txt"

SLEEP_TIME=15
FALSE=0
TRUE=1
#DEBUG=$FALSE
DEBUG=$TRUE

# export DOCKER_HOST="tcp://0.0.0.0:2375"
export CONTAINER_NAME=$SQUID_CONTAINER

# Get the squid container and retag it so the script can use it
getSquid(){
  docker pull $SQUID_IMAGE
  docker tag $SQUID_IMAGE $SQUID_CONTAINER
}

# Pull the latest test container
getTestContainer(){
  docker pull $TEST_CONTAINER
}

# Update the squid container and return if it was different or not
updateSquid(){
  UPDATED=$FALSE
  CURRENT_SQUID_ID=$(docker images $SQUID_IMAGE:latest -q)
  getSquid
  NEW_SQUID_ID=$(docker images $SQUID_IMAGE:latest -q)

  if [ "$CURRENT_SQUID_ID" != "$NEW_SQUID_ID" ]; then
    UPDATED=$TRUE
  fi

  return $UPDATED
}

# Check if the squid container exists
checkSquid(){
  docker ps | grep $CONTAINER_NAME > /dev/null
  return $?
}

# Stop the squid container
stopSquid() {
  docker stop $CONTAINER_NAME

  if [ "$?" != "0" ]; then
    echo "Problem stopping $CONTAINER_NAME"
    exit 1
  fi
}

# Start the squid container
startSquid() {
  nohup $RUN_FILE_LOCATION ssl &> /dev/null &

  if [ "$?" != "0" ]; then
    echo "Problem starting $CONTAINER_NAME"
    exit 2
  fi
}

# Restart the squid container
restartSquid() {

  stopSquid

  # Wait for clean exit
  sleep $SLEEP_TIME

  startSquid

  # Wait for a clean startup
  sleep $SLEEP_TIME
}

# Check if curl responds
checkCurlResponse(){
  MATCHES=$FALSE
  let i=0
  while [ $i -lt 2 ]; do

    # Curl a plain text file, for more complex files, consider converting to md5sum (or checkeing headers)
    HOST_RESPONSE=$(curl -sL $URL)

    #This has a \r in it, so we will sed it out
    CONTAINER_RESPONSE=$(docker run --name $TEST_CONTAINER_NAME -t $TEST_CONTAINER curl -sL $URL | sed 's/\r//g')
    docker rm $TEST_CONTAINER_NAME &> /dev/null
#    echo " docker rm $TEST_CONTAINER_NAME "


    if [ "$HOST_RESPONSE" == "$CONTAINER_RESPONSE" ]; then
      MATCHES=$TRUE
      break
    fi

    let i+=1
  done

  return $MATCHES
}

# Run the checker script
runChecks() {

  [ "$DEBUG" == "$TRUE" ] && echo "checkSquid"
  updateSquid
  UPDATED=$?

  # check if the squid container is running
  [ "$DEBUG" == "$TRUE" ] && echo "checkSquid"
  checkSquid
  if [ "$?" != "0" ]; then
    [ "$DEBUG" == "$TRUE" ] && echo "startSquid"
    startSquid
    sleep $SLEEP_TIME
  # If container has been updated and it is running, restart it
  elif [ "$UPDATED" == "$TRUE" ]; then
    [ "$DEBUG" == "$TRUE" ] && echo "restartSquid"
    restartSquid
  fi

  # check if we can curl
  [ "$DEBUG" == "$TRUE" ] && echo "checkCurlResponse"
  checkCurlResponse
  PROXY_WORKING=$?
  RESTARTED=$FALSE
  if [ "$PROXY_WORKING" == "$FALSE" ]; then
    [ "$DEBUG" == "$TRUE" ] && echo "restartSquid"
    restartSquid
    RESTARTED=$TRUE
  fi

  # We restarted the container so check again
  if [ $RESTARTED == $TRUE ]; then
    [ "$DEBUG" == "$TRUE" ] && echo "checkCurlResponse"
    checkCurlResponse
    PROXY_WORKING=$?
    if [ "$PROXY_WORKING" == "$FALSE" ]; then
      [ "$DEBUG" == "$TRUE" ] && echo "stopSquid"
      stopSquid
      echo "proxy failed"
      exit 4
    fi
  fi
  echo "proxy working"
  exit 0
}

# Run the program
getTestContainer
runChecks

