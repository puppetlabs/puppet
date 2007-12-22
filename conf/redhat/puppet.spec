%{!?ruby_sitelibdir: %define ruby_sitelibdir %(ruby -rrbconfig -e 'puts Config::CONFIG["sitelibdir"]')}
%define pbuild %{_builddir}/%{name}-%{version}
%define confdir conf/redhat

%define has_ruby_abi 0%{?fedora:%fedora} >= 5 || 0%{?rhel:%rhel} >= 5
%define has_ruby_noarch %has_ruby_abi

Summary: A network tool for managing many disparate systems
Name: puppet
Version: 0.24.1
Release: 1%{?dist}
License: GPLv2+
Group: System Environment/Base

URL: http://puppet.reductivelabs.com/
Source: http://reductivelabs.com/downloads/puppet/%{name}-%{version}.tgz

Requires: ruby >= 1.8.1
%if %has_ruby_abi
Requires: ruby(abi) = 1.8
%endif
Requires: facter >= 1.1.4
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
%if %has_ruby_noarch
BuildArchitectures: noarch
%endif
BuildRequires: ruby >= 1.8.1

%description
Puppet lets you centrally manage every important aspect of your system using a 
cross-platform specification language that manages all the separate elements 
normally aggregated in different files, like users, cron jobs, and hosts, 
along with obviously discrete elements like packages, services, and files.

%package server
Group: System Environment/Base
Summary: Server for the puppet system management tool
Requires: puppet = %{version}-%{release}

%description server
Provides the central puppet server daemon which provides manifests to clients.
The server can also function as a certificate authority and file server.

%prep
%setup -q

%build
for f in bin/* ; do 
  sed -i -e '1c#!/usr/bin/ruby' $f
done
# Fix some rpmlint complaints
for f in mac_dscl.pp mac_dscl_revert.pp \
         mac_netinfo.pp mac_pkgdmg.pp ; do
  sed -i -e'1d' examples/code/$f
  chmod a-x examples/code/$f
done

find examples/ -type f -empty | xargs rm
find examples/ -type f | xargs chmod a-x

%install
rm -rf %{buildroot}
install -d -m0755 %{buildroot}%{_sbindir}
install -d -m0755 %{buildroot}%{_bindir}
install -d -m0755 %{buildroot}%{ruby_sitelibdir}
install -d -m0755 %{buildroot}%{_sysconfdir}/puppet/manifests
install -d -m0755 %{buildroot}%{_docdir}/%{name}-%{version}
install -d -m0755 %{buildroot}%{_localstatedir}/lib/puppet
install -d -m0755 %{buildroot}%{_localstatedir}/run/puppet
install -d -m0755 %{buildroot}%{_localstatedir}/log/puppet
install -Dp -m0755 %{pbuild}/bin/* %{buildroot}%{_sbindir}
mv %{buildroot}%{_sbindir}/puppet %{buildroot}%{_bindir}/puppet
mv %{buildroot}%{_sbindir}/ralsh %{buildroot}%{_bindir}/ralsh
mv %{buildroot}%{_sbindir}/filebucket %{buildroot}%{_bindir}/filebucket
mv %{buildroot}%{_sbindir}/puppetrun %{buildroot}%{_bindir}/puppetrun
install -Dp -m0644 %{pbuild}/lib/puppet.rb %{buildroot}%{ruby_sitelibdir}/puppet.rb
cp -a %{pbuild}/lib/puppet %{buildroot}%{ruby_sitelibdir}
find %{buildroot}%{ruby_sitelibdir} -type f -perm +ugo+x -print0 | xargs -0 -r chmod a-x
install -Dp -m0644 %{confdir}/client.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/puppet
install -Dp -m0755 %{confdir}/client.init %{buildroot}%{_initrddir}/puppet
install -Dp -m0644 %{confdir}/server.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/puppetmaster
install -Dp -m0755 %{confdir}/server.init %{buildroot}%{_initrddir}/puppetmaster
install -Dp -m0644 %{confdir}/fileserver.conf %{buildroot}%{_sysconfdir}/puppet/fileserver.conf
install -Dp -m0644 %{confdir}/puppet.conf %{buildroot}%{_sysconfdir}/puppet/puppet.conf
install -Dp -m0644 %{confdir}/logrotate %{buildroot}%{_sysconfdir}/logrotate.d/puppet
# We need something for these ghosted files, otherwise rpmbuild
# will complain loudly. They won't be included in the binary packages
touch %{buildroot}%{_sysconfdir}/puppet/puppetmasterd.conf
touch %{buildroot}%{_sysconfdir}/puppet/puppetca.conf
touch %{buildroot}%{_sysconfdir}/puppet/puppetd.conf

%files
%defattr(-, root, root, 0755)
%{_bindir}/puppet
%{_bindir}/ralsh
%{_bindir}/filebucket
%{_sbindir}/puppetd
%{ruby_sitelibdir}/*
%{_initrddir}/puppet
%dir %{_sysconfdir}/puppet
%config(noreplace) %{_sysconfdir}/sysconfig/puppet
%config(noreplace) %{_sysconfdir}/puppet/puppet.conf
%ghost %config(noreplace,missingok) %{_sysconfdir}/puppet/puppetd.conf
%doc CHANGELOG COPYING LICENSE README examples
%exclude %{_sbindir}/puppetdoc
%config(noreplace) %{_sysconfdir}/logrotate.d/puppet
# These need to be owned by puppet so the server can
# write to them
%attr(-, puppet, puppet) %{_localstatedir}/run/puppet
%attr(-, puppet, puppet) %{_localstatedir}/log/puppet
%attr(-, puppet, puppet) %{_localstatedir}/lib/puppet

%files server
%defattr(-, root, root, 0755)
%{_sbindir}/puppetmasterd
%{_bindir}/puppetrun
%{_initrddir}/puppetmaster
%config(noreplace) %{_sysconfdir}/puppet/fileserver.conf
%dir %{_sysconfdir}/puppet/manifests
%config(noreplace) %{_sysconfdir}/sysconfig/puppetmaster
%ghost %config(noreplace,missingok) %{_sysconfdir}/puppet/puppetca.conf
%ghost %config(noreplace,missingok) %{_sysconfdir}/puppet/puppetmasterd.conf
%{_sbindir}/puppetca

%pre
/usr/sbin/groupadd -r puppet 2>/dev/null || :
/usr/sbin/useradd -g puppet -c "Puppet" \
    -s /sbin/nologin -r -d /var/lib/puppet puppet 2> /dev/null || :
if [ $1 -gt 1 ] ; then
  /usr/sbin/usermod -d /var/lib/puppet puppet || :
fi
%post
/sbin/chkconfig --add puppet
exit 0

%post server
/sbin/chkconfig --add puppetmaster

%preun
if [ "$1" = 0 ] ; then
  /sbin/service puppet stop > /dev/null 2>&1
  /sbin/chkconfig --del puppet
fi

%preun server
if [ "$1" = 0 ] ; then
  /sbin/service puppetmaster stop > /dev/null 2>&1
  /sbin/chkconfig --del puppetmaster
fi

%postun server
if [ "$1" -ge 1 ]; then
  /sbin/service puppetmaster condrestart > /dev/null 2>&1
fi

%clean
rm -rf %{buildroot}

%changelog
* Sat Dec 22 2007 David Lutterkort <dlutter@redhat.com> - 0.24.1-1
- New version

* Mon Dec 17 2007 David Lutterkort <dlutter@redhat.com> - 0.24.0-2
- Use updated upstream tarball that contains yumhelper.py

* Fri Dec 14 2007 David Lutterkort <dlutter@redhat.com> - 0.24.0-1
- Fixed license
- Munge examples/ to make rpmlint happier

* Wed Aug 22 2007 David Lutterkort <dlutter@redhat.com> - 0.23.2-1
- New version

* Thu Jul 26 2007 David Lutterkort <dlutter@redhat.com> - 0.23.1-1
- Remove old config files

* Wed Jun 20 2007 David Lutterkort <dlutter@redhat.com> - 0.23.0-1
- Install one puppet.conf instead of old config files, keep old configs 
  around to ease update
- Use plain shell commands in install instead of macros

* Wed May  2 2007 David Lutterkort <dlutter@redhat.com> - 0.22.4-1
- New version

* Thu Mar 29 2007 David Lutterkort <dlutter@redhat.com> - 0.22.3-1
- Claim ownership of _sysconfdir/puppet (bz 233908)

* Mon Mar 19 2007 David Lutterkort <dlutter@redhat.com> - 0.22.2-1
- Set puppet's homedir to /var/lib/puppet, not /var/puppet
- Remove no-lockdir patch, not needed anymore

* Mon Feb 12 2007 David Lutterkort <dlutter@redhat.com> - 0.22.1-2
- Fix bogus config parameter in puppetd.conf

* Sat Feb  3 2007 David Lutterkort <dlutter@redhat.com> - 0.22.1-1
- New version

* Fri Jan  5 2007 David Lutterkort <dlutter@redhat.com> - 0.22.0-1
- New version

* Mon Nov 20 2006 David Lutterkort <dlutter@redhat.com> - 0.20.1-2
- Make require ruby(abi) and buildarch: noarch conditional for fedora 5 or
  later to allow building on older fedora releases

* Mon Nov 13 2006 David Lutterkort <dlutter@redhat.com> - 0.20.1-1
- New version

* Mon Oct 23 2006 David Lutterkort <dlutter@redhat.com> - 0.20.0-1
- New version

* Tue Sep 26 2006 David Lutterkort <dlutter@redhat.com> - 0.19.3-1
- New version

* Mon Sep 18 2006 David Lutterkort <dlutter@redhat.com> - 0.19.1-1
- New version

* Thu Sep  7 2006 David Lutterkort <dlutter@redhat.com> - 0.19.0-1
- New version

* Tue Aug  1 2006 David Lutterkort <dlutter@redhat.com> - 0.18.4-2
- Use /usr/bin/ruby directly instead of /usr/bin/env ruby in
  executables. Otherwise, initscripts break since pidof can't find the
  right process

* Tue Aug  1 2006 David Lutterkort <dlutter@redhat.com> - 0.18.4-1
- New version

* Fri Jul 14 2006 David Lutterkort <dlutter@redhat.com> - 0.18.3-1
- New version

* Wed Jul  5 2006 David Lutterkort <dlutter@redhat.com> - 0.18.2-1
- New version

* Wed Jun 28 2006 David Lutterkort <dlutter@redhat.com> - 0.18.1-1
- Removed lsb-config.patch and yumrepo.patch since they are upstream now

* Mon Jun 19 2006 David Lutterkort <dlutter@redhat.com> - 0.18.0-1
- Patch config for LSB compliance (lsb-config.patch)
- Changed config moves /var/puppet to /var/lib/puppet, /etc/puppet/ssl 
  to /var/lib/puppet, /etc/puppet/clases.txt to /var/lib/puppet/classes.txt,
  /etc/puppet/localconfig.yaml to /var/lib/puppet/localconfig.yaml

* Fri May 19 2006 David Lutterkort <dlutter@redhat.com> - 0.17.2-1
- Added /usr/bin/puppetrun to server subpackage
- Backported patch for yumrepo type (yumrepo.patch)

* Wed May  3 2006 David Lutterkort <dlutter@redhat.com> - 0.16.4-1
- Rebuilt

* Fri Apr 21 2006 David Lutterkort <dlutter@redhat.com> - 0.16.0-1
- Fix default file permissions in server subpackage
- Run puppetmaster as user puppet
- rebuilt for 0.16.0

* Mon Apr 17 2006 David Lutterkort <dlutter@redhat.com> - 0.15.3-2
- Don't create empty log files in post-install scriptlet

* Fri Apr  7 2006 David Lutterkort <dlutter@redhat.com> - 0.15.3-1
- Rebuilt for new version

* Wed Mar 22 2006 David Lutterkort <dlutter@redhat.com> - 0.15.1-1
- Patch0: Run puppetmaster as root; running as puppet is not ready 
  for primetime

* Mon Mar 13 2006 David Lutterkort <dlutter@redhat.com> - 0.15.0-1
- Commented out noarch; requires fix for bz184199

* Mon Mar  6 2006 David Lutterkort <dlutter@redhat.com> - 0.14.0-1
- Added BuildRequires for ruby

* Wed Mar  1 2006 David Lutterkort <dlutter@redhat.com> - 0.13.5-1
- Removed use of fedora-usermgmt. It is not required for Fedora Extras and
  makes it unnecessarily hard to use this rpm outside of Fedora. Just
  allocate the puppet uid/gid dynamically

* Sun Feb 19 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-4
- Use fedora-usermgmt to create puppet user/group. Use uid/gid 24. Fixed 
problem with listing fileserver.conf and puppetmaster.conf twice

* Wed Feb  8 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-3
- Fix puppetd.conf

* Wed Feb  8 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-2
- Changes to run puppetmaster as user puppet

* Mon Feb  6 2006 David Lutterkort <dlutter@redhat.com> - 0.13.0-1
- Don't mark initscripts as config files

* Mon Feb  6 2006 David Lutterkort <dlutter@redhat.com> - 0.12.0-2
- Fix BuildRoot. Add dist to release

* Tue Jan 17 2006 David Lutterkort <dlutter@redhat.com> - 0.11.0-1
- Rebuild

* Thu Jan 12 2006 David Lutterkort <dlutter@redhat.com> - 0.10.2-1
- Updated for 0.10.2 Fixed minor kink in how Source is given

* Wed Jan 11 2006 David Lutterkort <dlutter@redhat.com> - 0.10.1-3
- Added basic fileserver.conf

* Wed Jan 11 2006 David Lutterkort <dlutter@redhat.com> - 0.10.1-1
- Updated. Moved installation of library files to sitelibdir. Pulled 
initscripts into separate files. Folded tools rpm into server

* Thu Nov 24 2005 Duane Griffin <d.griffin@psenterprise.com>
- Added init scripts for the client

* Wed Nov 23 2005 Duane Griffin <d.griffin@psenterprise.com>
- First packaging
