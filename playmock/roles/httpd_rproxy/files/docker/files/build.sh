#!/bin/bash
set -e

echo "*** hoge ***"
echo "=== Building mod_authn_otp RPM for Rocky Linux 8 ==="

# 変数設定
PACKAGE_NAME="mod_authn_otp"
VERSION="1.1.12"
SOURCE_URL="https://github.com/archiecobbs/mod-authn-otp/archive/refs/tags/${VERSION}.tar.gz"
SOURCE_FILE="${PACKAGE_NAME}-${VERSION}.tar.gz"
TEMP_FILE="${VERSION}.tar.gz"

# SOURCESディレクトリに移動
cd ~/rpmbuild/SOURCES

# ソースtarballをダウンロード
echo "Downloading source tarball..."
wget -O "${TEMP_FILE}" "${SOURCE_URL}"

if [ ! -f "${TEMP_FILE}" ]; then
    echo "ERROR: Failed to download source file"
    exit 1
fi

echo "Downloaded: ${TEMP_FILE}"
ls -la "${TEMP_FILE}"
tar --to-stdout -tvzf "${TEMP_FILE}" || { echo "ERROR: Failed to list contents of ${TEMP_FILE}"; exit 1; }

# ソースファイルを正しい名前にリネーム
tar -xzf "${TEMP_FILE}" -C /tmp
# Changelog, NEWS, AUTHORS, README, LICENSE, and COPYING files are not needed
find /tmp/mod-authn-otp-${VERSION} -type f -name 'configure.ac' -exec sed -i 's|^AM_INIT_AUTOMAKE|AM_INIT_AUTOMAKE([foreign])|' {} \;

tar -czvf "${SOURCE_FILE}" -C /tmp --transform "s|^mod-authn-otp-|${PACKAGE_NAME}-|" --show-transformed-names mod-authn-otp-${VERSION}/
if [ ! -f "${SOURCE_FILE}" ]; then
    echo "ERROR: Failed to create source file ${SOURCE_FILE}"
    exit 1
fi
tar -tvzf "${SOURCE_FILE}" || { echo "ERROR: Failed to list contents of ${SOURCE_FILE}"; exit 1; }

# rpmbuildディレクトリに戻る
cd ~/rpmbuild

# SPECファイルの存在確認
if [ ! -f "SPECS/mod_authn_otp.spec" ]; then
    echo "ERROR: SPECS/mod_authn_otp.spec not found"
    exit 1
fi

echo "Building RPM packages..."

# RPMをビルド
rpmbuild -ba SPECS/mod_authn_otp.spec

# ビルド結果の確認
echo ""
echo "=== Build Results ==="

if [ -d "RPMS/x86_64" ]; then
    echo "Binary RPMs:"
    ls -la RPMS/x86_64/*.rpm 2>/dev/null || echo "  No binary RPMs found"
fi

if [ -d "SRPMS" ]; then
    echo "Source RPMs:"
    ls -la SRPMS/*.rpm 2>/dev/null || echo "  No source RPMs found"
fi

echo ""
echo "=== Build Summary ==="
echo "Build completed successfully!"
echo ""
echo "To extract RPMs from the container, run:"
echo "  docker cp <container_name>:/home/rpmbuild/rpmbuild/RPMS/x86_64/ ./rpms/"
echo "  docker cp <container_name>:/home/rpmbuild/rpmbuild/SRPMS/ ./rpms/"
