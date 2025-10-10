# ビルドとRPM取得を一度に実行

docker build -t mod-authn-otp-builder . && \
docker run --name mod-authn-otp-build mod-authn-otp-builder && \
mkdir -p ./rpms > /dev/null 2>&1 && \
docker cp mod-authn-otp-build:/home/rpmbuild/rpmbuild/RPMS/x86_64/ ./rpms/ && \
docker cp mod-authn-otp-build:/home/rpmbuild/rpmbuild/SRPMS/ ./rpms/ && \
docker rm mod-authn-otp-build && \
echo "RPMs are ready in ./rpms/"
