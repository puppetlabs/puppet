---
layout: default
built_from_commit: 6893bdd69ab1291e6e6fcd6b152dda2b48e3cdb2
title: 'Resource Type: service'
canonical: "/puppet/latest/types/service.html"
---

# Resource Type: service

> **NOTE:** This page was generated from the Puppet source code on 2024-10-17 02:37:51 +0000



## service

* [Attributes](#service-attributes)
* [Providers](#service-providers)
* [Provider Features](#service-provider-features)

### Description {#service-description}

Manage running services.  Service support unfortunately varies
widely by platform --- some platforms have very little if any concept of a
running service, and some have a very codified and powerful concept.
Puppet's service support is usually capable of doing the right thing, but
the more information you can provide, the better behaviour you will get.

Puppet 2.7 and newer expect init scripts to have a working status command.
If this isn't the case for any of your services' init scripts, you will
need to set `hasstatus` to false and possibly specify a custom status
command in the `status` attribute. As a last resort, Puppet will attempt to
search the process table by calling whatever command is listed in the `ps`
fact. The default search pattern is the name of the service, but you can
specify it with the `pattern` attribute.

**Refresh:** `service` resources can respond to refresh events (via
`notify`, `subscribe`, or the `~>` arrow). If a `service` receives an
event from another resource, Puppet will restart the service it manages.
The actual command used to restart the service depends on the platform and
can be configured:

* If you set `hasrestart` to true, Puppet will use the init script's restart command.
* You can provide an explicit command for restarting with the `restart` attribute.
* If you do neither, the service's stop and start commands will be used.

### Attributes {#service-attributes}

<pre><code>service { 'resource title':
  <a href="#service-attribute-name">name</a>          =&gt; <em># <strong>(namevar)</strong> The name of the service to run.  This name is...</em>
  <a href="#service-attribute-ensure">ensure</a>        =&gt; <em># Whether a service should be running. Default...</em>
  <a href="#service-attribute-binary">binary</a>        =&gt; <em># The path to the daemon.  This is only used for...</em>
  <a href="#service-attribute-control">control</a>       =&gt; <em># The control variable used to manage services...</em>
  <a href="#service-attribute-enable">enable</a>        =&gt; <em># Whether a service should be enabled to start at...</em>
  <a href="#service-attribute-flags">flags</a>         =&gt; <em># Specify a string of flags to pass to the startup </em>
  <a href="#service-attribute-hasrestart">hasrestart</a>    =&gt; <em># Specify that an init script has a `restart...</em>
  <a href="#service-attribute-hasstatus">hasstatus</a>     =&gt; <em># Declare whether the service's init script has a...</em>
  <a href="#service-attribute-logonaccount">logonaccount</a>  =&gt; <em># Specify an account for service...</em>
  <a href="#service-attribute-logonpassword">logonpassword</a> =&gt; <em># Specify a password for service logon. Default...</em>
  <a href="#service-attribute-manifest">manifest</a>      =&gt; <em># Specify a command to config a service, or a path </em>
  <a href="#service-attribute-path">path</a>          =&gt; <em># The search path for finding init scripts....</em>
  <a href="#service-attribute-pattern">pattern</a>       =&gt; <em># The pattern to search for in the process table...</em>
  <a href="#service-attribute-provider">provider</a>      =&gt; <em># The specific backend to use for this `service...</em>
  <a href="#service-attribute-restart">restart</a>       =&gt; <em># Specify a *restart* command manually.  If left...</em>
  <a href="#service-attribute-start">start</a>         =&gt; <em># Specify a *start* command manually.  Most...</em>
  <a href="#service-attribute-status">status</a>        =&gt; <em># Specify a *status* command manually.  This...</em>
  <a href="#service-attribute-stop">stop</a>          =&gt; <em># Specify a *stop* command...</em>
  <a href="#service-attribute-timeout">timeout</a>       =&gt; <em># Specify an optional minimum timeout (in seconds) </em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#service-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the service to run.

This name is used to find the service; on platforms where services
have short system names and long display names, this should be the
short name. (To take an example from Windows, you would use "wuauserv"
rather than "Automatic Updates.")

([↑ Back to service attributes](#service-attributes))


#### ensure {#service-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

Whether a service should be running. Default values depend on the platform.

Allowed values:

* `stopped`
* `running`
* `false`
* `true`

([↑ Back to service attributes](#service-attributes))


#### binary {#service-attribute-binary}

The path to the daemon.  This is only used for
systems that do not support init scripts.  This binary will be
used to start the service if no `start` parameter is
provided.

([↑ Back to service attributes](#service-attributes))


#### control {#service-attribute-control}

The control variable used to manage services (originally for HP-UX).
Defaults to the upcased service name plus `START` replacing dots with
underscores, for those providers that support the `controllable` feature.

([↑ Back to service attributes](#service-attributes))


#### enable {#service-attribute-enable}

_(**Property:** This attribute represents concrete state on the target system.)_

Whether a service should be enabled to start at boot.
This property behaves differently depending on the platform;
wherever possible, it relies on local tools to enable or disable
a given service. Default values depend on the platform.

If you don't specify a value for the `enable` attribute, Puppet leaves
that aspect of the service alone and your operating system determines
the behavior.

Allowed values:

* `true`
* `false`
* `manual`
* `mask`
* `delayed`

Requires features enableable.

([↑ Back to service attributes](#service-attributes))


#### flags {#service-attribute-flags}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify a string of flags to pass to the startup script.

Requires features flaggable.

([↑ Back to service attributes](#service-attributes))


#### hasrestart {#service-attribute-hasrestart}

Specify that an init script has a `restart` command.  If this is
false and you do not specify a command in the `restart` attribute,
the init script's `stop` and `start` commands will be used.

Allowed values:

* `true`
* `false`

([↑ Back to service attributes](#service-attributes))


#### hasstatus {#service-attribute-hasstatus}

Declare whether the service's init script has a functional status
command. This attribute's default value changed in Puppet 2.7.0.

The init script's status command must return 0 if the service is
running and a nonzero value otherwise. Ideally, these exit codes
should conform to [the LSB's specification][lsb-exit-codes] for init
script status actions, but Puppet only considers the difference
between 0 and nonzero to be relevant.

If a service's init script does not support any kind of status command,
you should set `hasstatus` to false and either provide a specific
command using the `status` attribute or expect that Puppet will look for
the service name in the process table. Be aware that 'virtual' init
scripts (like 'network' under Red Hat systems) will respond poorly to
refresh events from other resources if you override the default behavior
without providing a status command.

Default: `true`

Allowed values:

* `true`
* `false`

([↑ Back to service attributes](#service-attributes))


#### logonaccount {#service-attribute-logonaccount}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify an account for service logon

Requires features manages_logon_credentials.

([↑ Back to service attributes](#service-attributes))


#### logonpassword {#service-attribute-logonpassword}

Specify a password for service logon. Default value is an empty string (when logonaccount is specified).

Requires features manages_logon_credentials.

([↑ Back to service attributes](#service-attributes))


#### manifest {#service-attribute-manifest}

Specify a command to config a service, or a path to a manifest to do so.

([↑ Back to service attributes](#service-attributes))


#### path {#service-attribute-path}

The search path for finding init scripts.  Multiple values should
be separated by colons or provided as an array.

([↑ Back to service attributes](#service-attributes))


#### pattern {#service-attribute-pattern}

The pattern to search for in the process table.
This is used for stopping services on platforms that do not
support init scripts, and is also used for determining service
status on those service whose init scripts do not include a status
command.

Defaults to the name of the service. The pattern can be a simple string
or any legal Ruby pattern, including regular expressions (which should
be quoted without enclosing slashes).

([↑ Back to service attributes](#service-attributes))


#### provider {#service-attribute-provider}

The specific backend to use for this `service` resource. You will seldom need to specify this --- Puppet will usually discover the appropriate provider for your platform.

Available providers are:

* [`base`](#service-provider-base)
* [`bsd`](#service-provider-bsd)
* [`daemontools`](#service-provider-daemontools)
* [`debian`](#service-provider-debian)
* [`freebsd`](#service-provider-freebsd)
* [`gentoo`](#service-provider-gentoo)
* [`init`](#service-provider-init)
* [`launchd`](#service-provider-launchd)
* [`openbsd`](#service-provider-openbsd)
* [`openrc`](#service-provider-openrc)
* [`openwrt`](#service-provider-openwrt)
* [`rcng`](#service-provider-rcng)
* [`redhat`](#service-provider-redhat)
* [`runit`](#service-provider-runit)
* [`service`](#service-provider-service)
* [`smf`](#service-provider-smf)
* [`src`](#service-provider-src)
* [`systemd`](#service-provider-systemd)
* [`upstart`](#service-provider-upstart)
* [`windows`](#service-provider-windows)

([↑ Back to service attributes](#service-attributes))


#### restart {#service-attribute-restart}

Specify a *restart* command manually.  If left
unspecified, the service will be stopped and then started.

([↑ Back to service attributes](#service-attributes))


#### start {#service-attribute-start}

Specify a *start* command manually.  Most service subsystems
support a `start` command, so this will not need to be
specified.

([↑ Back to service attributes](#service-attributes))


#### status {#service-attribute-status}

Specify a *status* command manually.  This command must
return 0 if the service is running and a nonzero value otherwise.
Ideally, these exit codes should conform to [the LSB's
specification][lsb-exit-codes] for init script status actions, but
Puppet only considers the difference between 0 and nonzero to be
relevant.

If left unspecified, the status of the service will be determined
automatically, usually by looking for the service in the process
table.

[lsb-exit-codes]: http://refspecs.linuxfoundation.org/LSB_4.1.0/LSB-Core-generic/LSB-Core-generic/iniscrptact.html

([↑ Back to service attributes](#service-attributes))


#### stop {#service-attribute-stop}

Specify a *stop* command manually.

([↑ Back to service attributes](#service-attributes))


#### timeout {#service-attribute-timeout}

Specify an optional minimum timeout (in seconds) for puppet to wait when syncing service properties

Requires features configurable_timeout.

([↑ Back to service attributes](#service-attributes))


### Providers {#service-providers}

#### base {#service-provider-base}

The simplest form of Unix service support.

You have to specify enough about your service for this to work; the
minimum you can specify is a binary for starting the process, and this
same binary will be searched for in the process table to stop the
service.  As with `init`-style services, it is preferable to specify start,
stop, and status commands.

* Required binaries: `kill`

#### bsd {#service-provider-bsd}

Generic BSD form of `init`-style service management with `rc.d`.

Uses `rc.conf.d` for service enabling and disabling.

* Confined to: `os.name == [:freebsd, :dragonfly]`

#### daemontools {#service-provider-daemontools}

Daemontools service management.

This provider manages daemons supervised by D.J. Bernstein daemontools.
When detecting the service directory it will check, in order of preference:

* `/service`
* `/etc/service`
* `/var/lib/svscan`

The daemon directory should be in one of the following locations:

* `/var/lib/service`
* `/etc`

...or this can be overridden in the resource's attributes:

    service { 'myservice':
      provider => 'daemontools',
      path     => '/path/to/daemons',
    }

This provider supports out of the box:

* start/stop (mapped to enable/disable)
* enable/disable
* restart
* status

If a service has `ensure => "running"`, it will link /path/to/daemon to
/path/to/service, which will automatically enable the service.

If a service has `ensure => "stopped"`, it will only shut down the service, not
remove the `/path/to/service` link.

* Required binaries: `/usr/bin/svc`, `/usr/bin/svstat`

#### debian {#service-provider-debian}

Debian's form of `init`-style management.

The only differences from `init` are support for enabling and disabling
services via `update-rc.d` and the ability to determine enabled status via
`invoke-rc.d`.

* Required binaries: `/usr/sbin/invoke-rc.d`, `/usr/sbin/service`, `/usr/sbin/update-rc.d`
* Confined to: `false == Puppet::FileSystem.exist?('/proc/1/comm') && Puppet::FileSystem.read('/proc/1/comm').include?('systemd')`
* Default for: `["os.name", "cumuluslinux"] == ["os.release.major", "%w[1 2]"]`, `["os.name", "debian"] == ["os.release.major", "%w[5 6 7]"]`, `["os.name", "devuan"] == `

#### freebsd {#service-provider-freebsd}

Provider for FreeBSD and DragonFly BSD. Uses the `rcvar` argument of init scripts and parses/edits rc files.

* Confined to: `os.name == [:freebsd, :dragonfly]`
* Default for: `["os.name", "[:freebsd, :dragonfly]"] == `

#### gentoo {#service-provider-gentoo}

Gentoo's form of `init`-style service management.

Uses `rc-update` for service enabling and disabling.

* Required binaries: `/sbin/rc-update`
* Confined to: `os.name == gentoo`

#### init {#service-provider-init}

Standard `init`-style service management.

* Confined to: `false == Puppet.runtime[:facter].value('os.family') == 'RedHat'`

#### launchd {#service-provider-launchd}

This provider manages jobs with `launchd`, which is the default service
framework for Mac OS X (and may be available for use on other platforms).

For more information, see the `launchd` man page:

* <https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man8/launchd.8.html>

This provider reads plists out of the following directories:

* `/System/Library/LaunchDaemons`
* `/System/Library/LaunchAgents`
* `/Library/LaunchDaemons`
* `/Library/LaunchAgents`

...and builds up a list of services based upon each plist's "Label" entry.

This provider supports:

* ensure => running/stopped,
* enable => true/false
* status
* restart

Here is how the Puppet states correspond to `launchd` states:

* stopped --- job unloaded
* started --- job loaded
* enabled --- 'Disable' removed from job plist file
* disabled --- 'Disable' added to job plist file

Note that this allows you to do something `launchctl` can't do, which is to
be in a state of "stopped/enabled" or "running/disabled".

Note that this provider does not support overriding 'restart'

* Required binaries: `/bin/launchctl`
* Confined to: `os.name == darwin`, `feature == cfpropertylist`
* Default for: `["os.name", "darwin"] == `
* Supported features: `enableable`, `refreshable`

#### openbsd {#service-provider-openbsd}

Provider for OpenBSD's rc.d daemon control scripts

* Required binaries: `/usr/sbin/rcctl`
* Confined to: `os.name == openbsd`
* Default for: `["os.name", "openbsd"] == `
* Supported features: `flaggable`

#### openrc {#service-provider-openrc}

Support for Gentoo's OpenRC initskripts

Uses rc-update, rc-status and rc-service to manage services.

* Required binaries: `/sbin/rc-service`, `/sbin/rc-update`
* Default for: `["os.name", "gentoo"] == `, `["os.name", "funtoo"] == `

#### openwrt {#service-provider-openwrt}

Support for OpenWrt flavored init scripts.

Uses /etc/init.d/service_name enable, disable, and enabled.

* Confined to: `os.name == openwrt`
* Default for: `["os.name", "openwrt"] == `
* Supported features: `enableable`

#### rcng {#service-provider-rcng}

RCng service management with rc.d

* Confined to: `os.name == [:netbsd, :cargos]`
* Default for: `["os.name", "[:netbsd, :cargos]"] == `

#### redhat {#service-provider-redhat}

Red Hat's (and probably many others') form of `init`-style service
management. Uses `chkconfig` for service enabling and disabling.

* Required binaries: `/sbin/chkconfig`, `/sbin/service`
* Default for: `["os.name", "amazon"] == ["os.release.major", "%w[2017 2018]"]`, `["os.name", "redhat"] == ["os.release.major", "(4..6).to_a"]`, `["os.family", "suse"] == ["os.release.major", "%w[10 11]"]`

#### runit {#service-provider-runit}

Runit service management.

This provider manages daemons running supervised by Runit.
When detecting the service directory it will check, in order of preference:

* `/service`
* `/etc/service`
* `/var/service`

The daemon directory should be in one of the following locations:

* `/etc/sv`
* `/var/lib/service`

or this can be overridden in the service resource parameters:

    service { 'myservice':
      provider => 'runit',
      path     => '/path/to/daemons',
    }

This provider supports out of the box:

* start/stop
* enable/disable
* restart
* status

* Required binaries: `/usr/bin/sv`

#### service {#service-provider-service}

The simplest form of service support.

#### smf {#service-provider-smf}

Support for Sun's new Service Management Framework.

When managing the enable property, this provider will try to preserve
the previous ensure state per the enableable semantics. On Solaris,
enabling a service starts it up while disabling a service stops it. Thus,
there's a chance for this provider to execute two operations when managing
the enable property. For example, if enable is set to true and the ensure
state is stopped, this provider will manage the service using two operations:
one to enable the service which will start it up, and another to stop the
service (without affecting its enabled status).

By specifying `manifest => "/path/to/service.xml"`, the SMF manifest will
be imported if it does not exist.

* Required binaries: `/usr/bin/svcs`, `/usr/sbin/svcadm`, `/usr/sbin/svccfg`
* Confined to: `os.family == solaris`
* Default for: `["os.family", "solaris"] == `
* Supported features: `refreshable`

#### src {#service-provider-src}

Support for AIX's System Resource controller.

Services are started/stopped based on the `stopsrc` and `startsrc`
commands, and some services can be refreshed with `refresh` command.

Enabling and disabling services is not supported, as it requires
modifications to `/etc/inittab`. Starting and stopping groups of subsystems
is not yet supported.

* Confined to: `os.name == aix`
* Default for: `["os.name", "aix"] == `
* Supported features: `refreshable`

#### systemd {#service-provider-systemd}

Manages `systemd` services using `systemctl`.

Because `systemd` defaults to assuming the `.service` unit type, the suffix
may be omitted.  Other unit types (such as `.path`) may be managed by
providing the proper suffix.

* Required binaries: `systemctl`
* Confined to: `true == Puppet::FileSystem.exist?('/proc/1/comm') && Puppet::FileSystem.read('/proc/1/comm').include?('systemd')`
* Default for: `["os.family", "[:archlinux]"] == `, `["os.family", "redhat"] == `, `["os.family", "redhat"] == ["os.name", "fedora"]`, `["os.family", "suse"] == `, `["os.family", "coreos"] == `, `["os.family", "gentoo"] == `, `["os.name", "amazon"] == ["os.release.major", "%w[2 2023]"]`, `["os.name", "debian"] == `, `["os.name", "LinuxMint"] == `, `["os.name", "ubuntu"] == `, `["os.name", "cumuluslinux"] == ["os.release.major", "%w[3 4]"]`, `["os.name", "raspbian"] == ["os.release.major", "%w[12]"]`

#### upstart {#service-provider-upstart}

Ubuntu service management with `upstart`.

This provider manages `upstart` jobs on Ubuntu. For `upstart` documentation,
see <http://upstart.ubuntu.com/>.

* Required binaries: `/sbin/initctl`, `/sbin/restart`, `/sbin/start`, `/sbin/status`, `/sbin/stop`
* Confined to: `any == [
    Puppet.runtime[:facter].value('os.name') == 'Ubuntu',
    (Puppet.runtime[:facter].value('os.family') == 'RedHat' and Puppet.runtime[:facter].value('os.release.full') =~ /^6\./),
    (Puppet.runtime[:facter].value('os.name') == 'Amazon' and Puppet.runtime[:facter].value('os.release.major') =~ /\d{4}/),
    Puppet.runtime[:facter].value('os.name') == 'LinuxMint'
  ]`, `true == -> { has_initctl? }`
* Default for: `["os.name", "ubuntu"] == ["os.release.major", "[\"10.04\", \"12.04\", \"14.04\", \"14.10\"]"]`, `["os.name", "LinuxMint"] == ["os.release.major", "%w[10 11 12 13 14 15 16 17]"]`
* Supported features: `enableable`

#### windows {#service-provider-windows}

Support for Windows Service Control Manager (SCM). This provider can
start, stop, enable, and disable services, and the SCM provides working
status methods for all services.

Control of service groups (dependencies) is not yet supported, nor is running
services as a specific user.

* Confined to: `os.name == windows`
* Default for: `["os.name", "windows"] == `
* Supported features: `configurable_timeout`, `manages_logon_credentials`, `refreshable`

### Provider Features {#service-provider-features}

Available features:

* `configurable_timeout` --- The provider can specify a minumum timeout for syncing service properties
* `controllable` --- The provider uses a control variable.
* `delayed_startable` --- The provider can set service to delayed start
* `enableable` --- The provider can enable and disable the service.
* `flaggable` --- The provider can pass flags to the service.
* `manages_logon_credentials` --- The provider can specify the logon credentials used for a service
* `manual_startable` --- The provider can set service to manual start
* `maskable` --- The provider can 'mask' the service.
* `refreshable` --- The provider can restart the service.

Provider support:

* **base** - No supported Provider features
* **bsd** - No supported Provider features
* **daemontools** - No supported Provider features
* **debian** - No supported Provider features
* **freebsd** - No supported Provider features
* **gentoo** - No supported Provider features
* **init** - No supported Provider features
* **launchd** - _enableable, refreshable_
* **openbsd** - _flaggable_
* **openrc** - No supported Provider features
* **openwrt** - _enableable_
* **rcng** - No supported Provider features
* **redhat** - No supported Provider features
* **runit** - No supported Provider features
* **service** - No supported Provider features
* **smf** - _refreshable_
* **src** - _refreshable_
* **systemd** - No supported Provider features
* **upstart** - _enableable_
* **windows** - _refreshable, configurable timeout, manages logon credentials_
  




