#!/bin/bash

# Run the sdo-owner-services container on the Horizon management hub (IoT platform/owner.

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << EndOfMessage
Usage: ${0##*/} [<image-version>] [<owner-private-key-file>]

Arguments:
  <image-version>  The image tag to use. Defaults to 'latest'
  <owner-private-key-file>  The p12 private key you have created to use with the sdo-owner-services. Must supply the corresponding public key to sample-mfg/simulate-mfg.sh. If the private key isn't specified here, the default is keys/sample-owner-keystore.p12

Required environment variables: HZN_EXCHANGE_URL, HZN_FSS_CSSURL, HZN_ORG_ID, HZN_MGMT_HUB_CERT (can be set to 'N/A' if the mgmt hub does no require a cert)

Recommended environment variables: DOCKER_REGISTRY, SDO_DOCKER_IMAGE
EndOfMessage
    exit 1
fi

# These env vars are required
: ${HZN_EXCHANGE_URL:?} ${HZN_FSS_CSSURL:?} ${HZN_MGMT_HUB_CERT:?} ${HZN_ORG_ID:?}
# If their mgmt hub doesn't need a self-signed cert, we chose to make them set HZN_MGMT_HUB_CERT to 'N/A' to ensure they didn't just forget to specify this env var
if [[ $HZN_MGMT_HUB_CERT == 'N/A' || $HZN_MGMT_HUB_CERT == 'n/a' ]]; then
    unset HZN_MGMT_HUB_CERT
fi

VERSION="${1:-latest}"
ownerPrivateKey="$2"
if [[ -n "$ownerPrivateKey" && ! -f "$ownerPrivateKey" ]]; then
    echo "Error: specified owner-private-key-file '$ownerPrivateKey' does not exist."
    exit 2
fi


DOCKER_REGISTRY=${DOCKER_REGISTRY:-openhorizon}
SDO_DOCKER_IMAGE=${SDO_DOCKER_IMAGE:-sdo-owner-services}
containerHome=/home/sdouser

#SDO_OCS_DB_HOST_DIR=${SDO_OCS_DB_HOST_DIR:-$PWD/ocs-db}  # we are now using a named volume instead of a host dir
# this is where OCS needs it to be
SDO_OCS_DB_CONTAINER_DIR=${SDO_OCS_DB_CONTAINER_DIR:-$containerHome/ocs/config/db}
OCS_API_PORT=${OCS_API_PORT:-9008}
# These can't be overridden easily
SDO_RV_PORT=${SDO_RV_PORT:-8040}
SDO_TO0_PORT=${SDO_TO0_PORT:-8049}
SDO_OPS_PORT=${SDO_OPS_PORT:-8042}

# Define the OPS hostname the to0scheduler tells RV to direct the booting device to
SDO_OWNER_SVC_HOST=${SDO_OWNER_SVC_HOST:-$(hostname)}

if [[ -n "$ownerPrivateKey" ]]; then
    privateKeyMount="-v $PWD/$ownerPrivateKey:$containerHome/ocs/config/owner-keystore.p12:ro"
fi
# else inside the container start-sdo-owner-services.sh will use the default key file that Dockerfile set up

# If VERSION==latest we have to make sure we pull the most recent
docker pull $DOCKER_REGISTRY/$SDO_DOCKER_IMAGE:$VERSION

# Run the service container
docker run --name $SDO_DOCKER_IMAGE -dt --mount "type=volume,src=sdo-ocs-db,dst=$SDO_OCS_DB_CONTAINER_DIR" $privateKeyMount -p $OCS_API_PORT:$OCS_API_PORT -p $SDO_RV_PORT:$SDO_RV_PORT -p $SDO_TO0_PORT:$SDO_TO0_PORT -p $SDO_OPS_PORT:$SDO_OPS_PORT -e "SDO_OWNER_SVC_HOST=$SDO_OWNER_SVC_HOST" -e "SDO_OCS_DB_PATH=$SDO_OCS_DB_CONTAINER_DIR" -e "OCS_API_PORT=$OCS_API_PORT" -e "HZN_EXCHANGE_URL=$HZN_EXCHANGE_URL" -e "HZN_FSS_CSSURL=$HZN_FSS_CSSURL" -e "HZN_ORG_ID=$HZN_ORG_ID" -e "HZN_MGMT_HUB_CERT=$HZN_MGMT_HUB_CERT" -e "SDO_SUPPORT_REPO=$SDO_SUPPORT_REPO" $DOCKER_REGISTRY/$SDO_DOCKER_IMAGE:$VERSION
