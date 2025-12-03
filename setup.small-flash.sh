set -e

# the inputs:
TARGET="${TARGET:-x86/64}"
VERSION_PATH="${VERSION_PATH:-snapshots}"
FILE_HOST="${UPSTREAM_URL:-${FILE_HOST:-https://firmware-libremesh.antennine.org/imagebuilders}}"
DOWNLOAD_FILE="${DOWNLOAD_FILE:-imagebuilder-.*x86_64.tar.[xz|zst]}"
DOWNLOAD_PATH="$VERSION_PATH/targets/$TARGET"
FEED_HOST="${FEED_HOST:-https://downloads.openwrt.org}"

wget -nv "$FILE_HOST/$DOWNLOAD_PATH/sha256sums" -O sha256sums
#wget -nv "$FILE_HOST/$DOWNLOAD_PATH/sha256sums.asc" -O sha256sums.asc

#gpg --import /builder/keys/*.asc && rm -rf /builder/keys/
#gpg --with-fingerprint --verify sha256sums.asc sha256sums

# determine archive name
file_name="$(grep "$DOWNLOAD_FILE" sha256sums | cut -d "*" -f 2)"

# download imagebuilder/sdk archive
wget -nv "$FILE_HOST/$DOWNLOAD_PATH/$file_name"

# shrink checksum file to single desired file and verify downloaded archive
grep "$file_name" sha256sums > sha256sums_min
cat sha256sums_min
sha256sum -c sha256sums_min

# cleanup
rm -vrf sha256sums{,_min,.asc} keys/

tar xf "$file_name" --strip=1 --no-same-owner -C .
rm -vrf "$file_name"

# setup packages repositories
# due to not selecting CONFIG_IB_STANDALONE in the buildroot:
# - all kmods are already included in /builder/packages
# - repositories file doesn't contains packages feeds.
arch=$(grep CONFIG_TARGET_ARCH_PACKAGES .config | sed 's|.*=\"\(.*\)\"|\1|')
openwrt_feeds="base luci packages routing telephony"
tmp_feeds="repositories_feeds"

# apk
pkg_manager="apk"
packages_db="/packages.adb"
repo_file="repositories"

# opkg
if [ $(echo "$VERSION_PATH" | cut -d "/" -f2 | cut -c1-2) -lt 25 ]; then
	pkg_manager="opkg"
	packages_db=""
	repo_file="repositories.conf"
fi

for feed in ${openwrt_feeds}; do
	if [ $pkg_manager == "opkg" ]; then
		echo "src/gz openwrt_${feed} ${FEED_HOST}/${VERSION_PATH}/packages/${arch}/${feed}${packages_db}" >> $tmp_feeds
	else 
		echo "${FEED_HOST}/${VERSION_PATH}/packages/${arch}/${feed}${packages_db}" >> $tmp_feeds
	fi
done

cat $repo_file >> $tmp_feeds; mv $tmp_feeds $repo_file
