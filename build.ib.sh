#!/bin/bash

# Example of usage:
#
# REF=openwrt-24.10 && nohup ./build.ib.sh > nohup.$REF &

FILE_HOST=${FILE_HOST:-"http://openwrt.mirror.garr.it/openwrt"}
BASE_CONTAINER="docker.io/agave0/openwrt-imagebuilder"
REF=${REF:-main}
EXTRA_IMAGE_NAME=${EXTRA_IMAGE_NAME}
TARGET=${TARGET}
RUN_SETUP=0
DISTRO=${DISTRO:-"alpine"}

case $DISTRO in
  alpine)
    DOCKERFILE=Dockerfile.alpine
    DISTRO_TAG="-alpine"
  ;;  
  debian)
    DOCKERFILE=Dockerfile
    DISTRO_TAG=""
  ;;  
esac

case $REF in
  main)
    VERSION=master
    VERSION_PATH=snapshots
  ;;
  openwrt-*)
    REF_PATH=${REF//openwrt-/}-SNAPSHOT
    VERSION=${REF}
    VERSION_PATH=releases/${REF_PATH}
  ;;
  v*)
    VERSION=${REF}
    VERSION_PATH=releases/${VERSION//v/}
    RUN_SETUP=1
  ;;
  *)
    echo "No tag or branch found"
    exit 1
  ;;
esac

VERSION_TAG="-${VERSION}${DISTRO_TAG}${EXTRA_IMAGE_NAME}"

build () {
  TAG=${BASE_CONTAINER}:${1/\//-}${VERSION_TAG}
  podman build . \
  --build-arg VERSION_PATH=$VERSION_PATH \
  --build-arg TARGET=$1 \
  --build-arg RUN_SETUP=$RUN_SETUP \
  --build-arg UPSTREAM_URL=$FILE_HOST \
  --build-arg FILE_HOST=$FILE_HOST \
  --file $DOCKERFILE \
  --tag ${TAG}
}

if [ -z "$TARGET" ]; then
  targets=($(curl -s "https://downloads.openwrt.org/${VERSION_PATH}/.targets.json" | jq -r 'keys.[]' ))

  for i in ${!targets[@]}; do 
    echo "$(($i+1))/${#targets[@]} - Building ${targets[$i]}"
    build ${targets[$i]}
  done

else
    build $TARGET
fi
