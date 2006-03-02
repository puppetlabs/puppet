%define rubylibdir %(ruby -rrbconfig -e 'puts Config::CONFIG["sitelibdir"]')
%define _pbuild %{_builddir}/%{name}-%{version}
%define confdir conf/redhat

Summary: A network tool for managing many disparate systems
Name: puppet
Version: 0.13.5
Release: 1%{?dist}
License: GPL
Group: System Environment/Base

URL: http://reductivelabs.com/projects/puppet/
Source: http://reductivelabs.com/downloads/puppet/%{name}-%{version}.tgz

Requires: ruby >= 1.8.1
Requires: facter >= 1.1
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArchitectures: noarch

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

%install
%{__rm} -rf %{buildroot}
%{__install} -d -m0755 %{buildroot}%{_sbindir}
%{__install} -d -m0755 %{buildroot}%{_bindir}
%{__install} -d -m0755 %{buildroot}%{rubylibdir}
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/puppet/manifests
%{__install} -d -m0755 %{buildroot}%{_docdir}/%{name}-%{version}
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/puppet
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/run/puppet
%{__install} -d -m0755 %{buildroot}%{_localstatedir}/log/puppet
%{__install} -Dp -m0755 %{_pbuild}/bin/* %{buildroot}%{_sbindir}
%{__mv} %{buildroot}%{_sbindir}/puppet %{buildroot}%{_bindir}/puppet
%{__install} -Dp -m0644 %{_pbuild}/lib/puppet.rb %{buildroot}%{rubylibdir}/puppet.rb
%{__cp} -a %{_pbuild}/lib/puppet %{buildroot}%{rubylibdir}
find %{buildroot}%{rubylibdir} -type f -perm +ugo+x -print0 | xargs -0 -r %{__chmod} a-x
%{__install} -Dp -m0644 %{confdir}/client.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/puppet
%{__install} -Dp -m0755 %{confdir}/client.init %{buildroot}%{_initrddir}/puppet
%{__install} -Dp -m0644 %{confdir}/server.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/puppetmaster
%{__install} -Dp -m0755 %{confdir}/server.init %{buildroot}%{_initrddir}/puppetmaster
%{__install} -Dp -m0644 %{confdir}/fileserver.conf %{buildroot}%{_sysconfdir}/puppet/fileserver.conf
%{__install} -Dp -m0644 %{confdir}/puppetd.conf %{buildroot}%{_sysconfdir}/puppet/puppetd.conf
%{__install} -Dp -m0644 %{confdir}/puppetmasterd.conf %{buildroot}%{_sysconfdir}/puppet/puppetmasterd.conf
%{__install} -Dp -m0644 %{confdir}/logrotate %{buildroot}%{_sysconfdir}/logrotate.d/puppet

%files
%defattr(-, root, root, 0755)
%{_bindir}/puppet
%{_sbindir}/puppetd
%{rubylibdir}/*
%{_localstatedir}/puppet
%{_initrddir}/puppet
%config(noreplace) %{_sysconfdir}/sysconfig/puppet
%config(noreplace) %{_sysconfdir}/puppet/puppetd.conf
%doc CHANGELOG COPYING LICENSE README TODO examples
%exclude %{_sbindir}/puppetdoc
%config(noreplace) %{_sysconfdir}/logrotate.d/puppet
# These need to be owned by puppet so the server can
# write to them
%attr(-, puppet, puppet) %{_localstatedir}/run/puppet
%attr(-, puppet, puppet) %{_localstatedir}/log/puppet

%files server
%{_sbindir}/puppetmasterd
%{_initrddir}/puppetmaster
%config(noreplace) %{_sysconfdir}/puppet/*
%config(noreplace) %{_sysconfdir}/sysconfig/puppetmaster
%{_sbindir}/cf2puppet
%{_sbindir}/puppetca

%pre
/usr/sbin/groupadd -r puppet 2>/dev/null || :
/usr/sbin/useradd -g puppet -c "Puppet" \
    -s /sbin/nologin -r -d /var/puppet puppet 2> /dev/null || :

%post
touch %{_localstatedir}/log/puppet.log
/sbin/chkconfig --add puppet
exit 0

%post server
touch %{_localstatedir}/log/puppetmaster.log
touch %{_localstatedir}/log/puppetmaster-http.log
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
%{__rm} -rf %{buildroot}

%changelog
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
