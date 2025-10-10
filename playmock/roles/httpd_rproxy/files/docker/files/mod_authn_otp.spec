# mod_authn_otp.spec - Rocky Linux 8 向け
# openSUSE Build Serviceの成功例を基に作成

%global debug_package %{nil}

%define apache_version 2.4.37
%define apache_dir /etc/httpd
%define apache_libdir %{_libdir}/httpd
%define apache_modules_dir %{apache_libdir}/modules

Name:           mod_authn_otp
Version:        1.1.12
Release:        1%{?dist}
Summary:        Apache module for one-time password authentication

License:        Apache-2.0
URL:            https://github.com/archiecobbs/mod-authn-otp
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  httpd-devel >= %{apache_version}
BuildRequires:  openssl-devel
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
BuildRequires:  make
BuildRequires:  gcc

Requires:       httpd >= %{apache_version}

%description
mod_authn_otp is an Apache web server module for two-factor authentication 
using one-time passwords (OTP) generated via the HOTP/OATH algorithm defined 
in RFC 4226. This creates a simple way to protect a web site with one-time 
passwords, using any RFC 4226-compliant hardware or software token device.

mod_authn_otp supports both event and time based one-time passwords. It also 
supports "lingering" which allows the repeated re-use of a previously used 
one-time password up to a configurable maximum linger time.

%prep
%autosetup -n %{name}-%{version}

%build
# autoreconfを実行
autoreconf -fiv

# configureを実行
%configure --with-apxs=%{_bindir}/apxs

# ビルド実行
%make_build

%install
# インストール実行
%make_install

# モジュール設定ディレクトリを作成
mkdir -p %{buildroot}%{apache_dir}/conf.modules.d

# モジュール読み込み設定をコピー
install -m 644 /tmp/10-auth_otp.conf %{buildroot}%{apache_dir}/conf.modules.d/

%files
%{apache_modules_dir}/%{name}.so
%config(noreplace) %{apache_dir}/conf.modules.d/10-auth_otp.conf
%defattr(-,root,root,-)
/usr/bin/genotpurl
/usr/bin/otplock
/usr/bin/otptool
/usr/share/man/man1/genotpurl.1.gz
/usr/share/man/man1/otplock.1.gz
/usr/share/man/man1/otptool.1.gz

%post
# Apacheの設定テスト
if /usr/sbin/httpd -t > /dev/null 2>&1; then
    # 設定が正常な場合、graceful reload を試行
    /bin/systemctl try-reload-or-restart httpd.service > /dev/null 2>&1 || :
fi

%postun
if [ $1 -eq 0 ]; then
    # アンインストール時、graceful reload を試行
    /bin/systemctl try-reload-or-restart httpd.service > /dev/null 2>&1 || :
fi

%changelog
* %(date "+%%a %%b %%d %%Y") rpmbuild <rpmbuild@localhost> - %{version}-%{release}
- Initial RPM build for Rocky Linux 8 based on openSUSE Build Service
- Auto-generated changelog entry
