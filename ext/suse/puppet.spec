#
# spec file for package puppet
#
# Copyright (c) 2012 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


# backward compatible requirement SLE...
%{?!_initddir:%define _initddir %_initrddir}

%define _fwdefdir /etc/sysconfig/SuSEfirewall2.d/services

Name:           puppet
Version:        3.3.1
Release:        0
Summary:        A network tool for managing many disparate systems
License:        Apache-2.0
Group:          Productivity/Networking/System
Url:            http://puppetlabs.com/puppet/what-is-puppet/
Source:         http://downloads.puppetlabs.com/puppet/%{name}-%{version}.tar.gz
Source1:        puppetmaster.fw
Source2:        puppet.fw
Source3:        puppet.sysconfig
Source4:        puppetmasterd.sysconfig
Source5:	puppetagent.service
Source6:        puppet.changelog
# PATCH-MISSING-TAG -- See http://wiki.opensuse.org/openSUSE:Packaging_Patches_guidelines
Patch0:         puppet-2.6.6-yumconf.diff
# PATCH-FIX-OPENSUSE puppet-3.0.2-init.diff aeszter@gwdg.de -- 2013-11-02 refactored boris@steki.net fix masterport
Patch1:         puppet-3.0.2-init.patch
Obsoletes:      hiera-puppet < 1.0.0
Provides:       hiera-puppet >= 1.0.0
Requires:       facter >= 1.6.4
Requires:       rubygem-hiera >= 1.0.0
Requires:       ruby >= 1.8.7
Requires:       rubygem-ruby-shadow >= 2.1.4
BuildRequires:  facter >= 1.6.11
BuildRequires:  fdupes
BuildRequires:  ruby >= 1.8.7
BuildRequires:  rubygem-hiera >= 1.0.0
# not really required but we do not wanna own their folders
BuildRequires:  vim
BuildRequires:  emacs-nox

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Requires(pre):  %fillup_prereq
Requires(pre):  %insserv_prereq
Requires(pre):  /usr/sbin/groupadd
Requires(pre):  /usr/sbin/useradd
%if 0%{?suse_version} >= 1210
BuildRequires:  systemd
%endif

%if %suse_version > 1220
%define         _unitdir /usr/lib/systemd
%else
%define         _unitdir /lib/systemd
%endif

%description
Puppet lets you centrally manage every important aspect of your system
using a cross-platform specification language that manages all the
separate elements normally aggregated in different files, like users,
cron jobs, and hosts, along with obviously discrete elements like
packages, services, and files.

%package server
Summary:        A network tool for managing many disparate systems
Group:          Productivity/Networking/System
Requires(pre):  %fillup_prereq
Requires(pre):  %insserv_prereq
Requires(pre):  puppet = %{version}

%description server
Puppet lets you centrally manage every important aspect of your system
using a cross-platform specification language that manages all the
separate elements normally aggregated in different files, like users,
cron jobs, and hosts, along with obviously discrete elements like
packages, services, and files.

%prep
%setup -q
%patch0
%patch1
cp %{S:6} ChangeLog

%build

%install
ruby install.rb install --destdir=%{buildroot} --sitelibdir=%{_libdir}/ruby/vendor_ruby/%{rb_ver}
mkdir -p %{buildroot}%{_sysconfdir}/puppet
mkdir -p %{buildroot}%{_sysconfdir}/init.d
mkdir -p %{buildroot}/%{_sbindir}
mkdir -p %{buildroot}%{_localstatedir}/lib/puppet
mkdir -p %{buildroot}%{_localstatedir}/log/puppet
mkdir -p %{buildroot}/%{_fwdefdir}
%if 0%{?suse_version} >= 1210
mkdir -p %{buildroot}%{_unitdir}/system
%endif
install -m0644 ext/redhat/puppet.conf %{buildroot}%{_sysconfdir}/puppet/puppet.conf
install -m0644 conf/auth.conf %{buildroot}%{_sysconfdir}/puppet/auth.conf
install -m0755 ext/suse/client.init %{buildroot}%{_initddir}/puppet
install -m0755 ext/suse/server.init %{buildroot}%{_initddir}/puppetmasterd
ln -sf ../../etc/init.d/puppet %{buildroot}/%{_sbindir}/rcpuppet
ln -sf ../../etc/init.d/puppetmasterd %{buildroot}/%{_sbindir}/rcpuppetmasterd
install -m 644 %{SOURCE1} %{buildroot}/%{_fwdefdir}/puppetmasterd
install -m 644 %{SOURCE2} %{buildroot}/%{_fwdefdir}/puppet
%if 0%{?suse_version} >= 1210
install -m 644 %{SOURCE5} %{buildroot}%{_unitdir}/system/puppetagent.service
install -m 644 ext/systemd/puppetmaster.service %{buildroot}%{_unitdir}/system/puppetmaster.service
%endif
mkdir -p %{buildroot}%{_localstatedir}/adm/fillup-templates
cp %{SOURCE3} %{buildroot}%{_localstatedir}/adm/fillup-templates/sysconfig.puppet
cp %{SOURCE4} %{buildroot}%{_localstatedir}/adm/fillup-templates/sysconfig.puppetmasterd
%fdupes -s %{buildroot}/%{_mandir}

# puppet ext/ data
install -d -m0755 %{buildroot}%{_datadir}/%{name}
install -d -m0755 %{buildroot}%{_datadir}/%{name}/ext

# be specific, we don't need/want the OS specific stuff
for ii in \
    autotest \
    cert_inspector \
    dbfix.sql \
    envpuppet \
    ldap \
    logcheck \
    nagios \
    puppetlisten \
    puppet-load.rb \
    puppet-test \
    pure_ruby_dsl \
    rack \
    regexp_nodes \
    upload_facts.rb \
    yaml_nodes.rb 
do
    cp -a ext/$ii %{buildroot}%{_datadir}/%{name}/ext
done

# Install vim syntax files
vimdir=%{buildroot}%{_datadir}/vim/site
install -Dp -m0644 ext/vim/ftdetect/puppet.vim $vimdir/ftdetect/puppet.vim
install -Dp -m0644 ext/vim/syntax/puppet.vim $vimdir/syntax/puppet.vim

# Install emacs mode files
emacsdir=%{buildroot}%{_datadir}/emacs/site-lisp
install -Dp -m0644 ext/emacs/puppet-mode.el $emacsdir/puppet-mode.el
install -Dp -m0644 ext/emacs/puppet-mode-init.el \
    $emacsdir/site-start.d/puppet-mode-init.el

%pre
getent group puppet >/dev/null || /usr/sbin/groupadd -r puppet
getent passwd puppet >/dev/null || /usr/sbin/useradd -r -g puppet -d /var/lib/puppet -s /bin/false -c "Puppet daemon" puppet

%preun
%stop_on_removal puppet

%postun
%restart_on_update puppet
%insserv_cleanup

%post
%fillup_and_insserv

%preun server
%stop_on_removal puppetmasterd

%post server
%fillup_and_insserv -f

%postun server
%restart_on_update puppetmasterd
%insserv_cleanup

%files
%defattr(-,root,root,-)
%doc LICENSE README.* ChangeLog
%{_bindir}/puppet
%{_bindir}/extlookup2hiera
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/puppet/
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/hiera/
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/hiera_puppet.rb
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/puppet.rb
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/semver.rb
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/puppetx.rb
%{_libdir}/ruby/vendor_ruby/%{rb_ver}/puppetx/
%dir %{_sysconfdir}/puppet
%dir %{_localstatedir}/lib/puppet
%dir %{_localstatedir}/log/puppet
# emacs-mode files
%{_datadir}/emacs/site-lisp/puppet-mode.el
# emacs by default does not own it so we must own it...
%dir %{_datadir}/emacs/site-lisp/site-start.d
%{_datadir}/emacs/site-lisp/site-start.d/puppet-mode-init.el
# vim support files
%{_datadir}/vim/site/ftdetect/puppet.vim
%{_datadir}/vim/site/syntax/puppet.vim
# puppet extensions
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/ext
%{_datadir}/%{name}/ext/autotest
%{_datadir}/%{name}/ext/cert_inspector
%{_datadir}/%{name}/ext/dbfix.sql
%{_datadir}/%{name}/ext/envpuppet
%{_datadir}/%{name}/ext/ldap
%{_datadir}/%{name}/ext/logcheck
%{_datadir}/%{name}/ext/nagios
%{_datadir}/%{name}/ext/puppetlisten
%{_datadir}/%{name}/ext/puppet-load.rb
%{_datadir}/%{name}/ext/puppet-test
%{_datadir}/%{name}/ext/pure_ruby_dsl
%{_datadir}/%{name}/ext/rack
%{_datadir}/%{name}/ext/regexp_nodes
%{_datadir}/%{name}/ext/upload_facts.rb
%{_datadir}/%{name}/ext/yaml_nodes.rb
#
%config %{_sysconfdir}/puppet/puppet.conf
%config %{_sysconfdir}/puppet/auth.conf
%{_mandir}/man?/*
%{_sysconfdir}/init.d/puppet
%{_sbindir}/rcpuppet
%config %{_fwdefdir}/puppet
%{_localstatedir}/adm/fillup-templates/sysconfig.puppet
%if 0%{?suse_version} >= 1210
%{_unitdir}/system/puppetagent.service
%endif

%files server
%defattr(-, root, root, 0755)
%dir %attr(755,root,root)
%{_sbindir}/rcpuppetmasterd
%{_sysconfdir}/init.d/puppetmasterd
%config %{_fwdefdir}/puppetmasterd
%{_localstatedir}/adm/fillup-templates/sysconfig.puppetmasterd
%if 0%{?suse_version} >= 1210
%{_unitdir}/system/puppetmaster.service
%endif

%changelog
