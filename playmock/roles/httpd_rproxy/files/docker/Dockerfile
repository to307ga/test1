FROM rockylinux:8

# 必要なパッケージをインストール
RUN dnf -y update && \
    dnf -y install epel-release && \
    dnf -y groupinstall "Development Tools" && \
    dnf -y install \
        rpm-build \
        rpmdevtools \
        httpd-devel \
        openssl-devel \
        git \
        autoconf \
        automake \
        libtool \
        make \
        gcc \
        wget \
        which

# rpmbuildユーザーを作成
RUN useradd -m rpmbuild

# 作業ディレクトリの所有者を変更
RUN chown rpmbuild:rpmbuild /home/rpmbuild

# rpmbuildユーザーに切り替え
USER rpmbuild
WORKDIR /home/rpmbuild

# RPMビルド環境をセットアップ
RUN rpmdev-setuptree

# 外部ファイルをコピー
COPY --chown=rpmbuild:rpmbuild files/mod_authn_otp.spec rpmbuild/SPECS/
COPY --chown=rpmbuild:rpmbuild files/build.sh .
COPY --chown=rpmbuild:rpmbuild files/10-auth_otp.conf /tmp/

# スクリプトに実行権限を付与
RUN chmod +x build.sh

# エントリーポイントとしてビルドスクリプトを設定
CMD ["./build.sh"]
