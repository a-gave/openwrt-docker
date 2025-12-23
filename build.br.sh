#!/bin/bash

# Example of usage:
#
# export REF=openwrt-24.10 TARGET=ath79/generic && REF=$REF TARGET=$TARGET nohup ./build.br.sh > nohup.$REF &

BASE_CONTAINER="docker.io/agave0/openwrt-buildroot"
REF=${REF:-main}
EXTRA_IMAGE_NAME=${EXTRA_IMAGE_NAME}
TARGET=${TARGET}
DISTRO=${DISTRO:-"debian"}

case $DISTRO in
  alpine)
    DOCKERFILE=Dockerfile.buildroot.ext_tools-toolchain.small-flash.alpine
    DISTRO_TAG="-alpine-small-flash"
  ;;  
  debian)
    DOCKERFILE=Dockerfile.buildroot.ext_tools-toolchain.small-flash
    DISTRO_TAG="-small-flash"
  ;;  
esac

case $REF in
  main)
    VERSION=SNAPSHOT
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
  ;;
  *)
    echo "No tag or branch found"
    exit 1
  ;;
esac

VERSION_TAG="-${VERSION}${DISTRO_TAG}${EXTRA_IMAGE_NAME}"

build () {
  TAG=${BASE_CONTAINER}:${1/\//-}${VERSION_TAG}
  docker build . \
  --build-arg TARGET=$1 \
  --build-arg OPENWRT_VERSION=$VERSION \
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
