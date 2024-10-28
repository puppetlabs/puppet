---
layout: default
built_from_commit: 8fcce5cb0d88b7330540e59817a7e6eae7adcdea
title: 'Resource Type: package'
canonical: "/puppet/latest/types/package.html"
---

# Resource Type: package

> **NOTE:** This page was generated from the Puppet source code on 2024-10-28 17:41:23 +0000



## package

* [Attributes](#package-attributes)
* [Providers](#package-providers)
* [Provider Features](#package-provider-features)

### Description {#package-description}

Manage packages.  There is a basic dichotomy in package
support right now:  Some package types (such as yum and apt) can
retrieve their own package files, while others (such as rpm and sun)
cannot.  For those package formats that cannot retrieve their own files,
you can use the `source` parameter to point to the correct file.

Puppet will automatically guess the packaging format that you are
using based on the platform you are on, but you can override it
using the `provider` parameter; each provider defines what it
requires in order to function, and you must meet those requirements
to use a given provider.

You can declare multiple package resources with the same `name` as long
as they have unique titles, and specify different providers and commands.

Note that you must use the _title_ to make a reference to a package
resource; `Package[<NAME>]` is not a synonym for `Package[<TITLE>]` like
it is for many other resource types.

**Autorequires:** If Puppet is managing the files specified as a
package's `adminfile`, `responsefile`, or `source`, the package
resource will autorequire those files.

### Attributes {#package-attributes}

<pre><code>package { 'resource title':
  <a href="#package-attribute-command">command</a>              =&gt; <em># <strong>(namevar)</strong> The targeted command to use when managing a...</em>
  <a href="#package-attribute-name">name</a>                 =&gt; <em># <strong>(namevar)</strong> The package name.  This is the name that the...</em>
  <a href="#package-attribute-ensure">ensure</a>               =&gt; <em># What state the package should be in. On...</em>
  <a href="#package-attribute-adminfile">adminfile</a>            =&gt; <em># A file containing package defaults for...</em>
  <a href="#package-attribute-allow_virtual">allow_virtual</a>        =&gt; <em># Specifies if virtual package names are allowed...</em>
  <a href="#package-attribute-allowcdrom">allowcdrom</a>           =&gt; <em># Tells apt to allow cdrom sources in the...</em>
  <a href="#package-attribute-category">category</a>             =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-configfiles">configfiles</a>          =&gt; <em># Whether to keep or replace modified config files </em>
  <a href="#package-attribute-description">description</a>          =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-enable_only">enable_only</a>          =&gt; <em># Tells `dnf module` to only enable a specific...</em>
  <a href="#package-attribute-flavor">flavor</a>               =&gt; <em># OpenBSD and DNF modules support 'flavors', which </em>
  <a href="#package-attribute-install_only">install_only</a>         =&gt; <em># It should be set for packages that should only...</em>
  <a href="#package-attribute-install_options">install_options</a>      =&gt; <em># An array of additional options to pass when...</em>
  <a href="#package-attribute-instance">instance</a>             =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-mark">mark</a>                 =&gt; <em># Set to hold to tell Debian apt/Solaris pkg to...</em>
  <a href="#package-attribute-package_settings">package_settings</a>     =&gt; <em># Settings that can change the contents or...</em>
  <a href="#package-attribute-platform">platform</a>             =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-provider">provider</a>             =&gt; <em># The specific backend to use for this `package...</em>
  <a href="#package-attribute-reinstall_on_refresh">reinstall_on_refresh</a> =&gt; <em># Whether this resource should respond to refresh...</em>
  <a href="#package-attribute-responsefile">responsefile</a>         =&gt; <em># A file containing any necessary answers to...</em>
  <a href="#package-attribute-root">root</a>                 =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-source">source</a>               =&gt; <em># Where to find the package file. This is mostly...</em>
  <a href="#package-attribute-status">status</a>               =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-uninstall_options">uninstall_options</a>    =&gt; <em># An array of additional options to pass when...</em>
  <a href="#package-attribute-vendor">vendor</a>               =&gt; <em># A read-only parameter set by the...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### command {#package-attribute-command}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The targeted command to use when managing a package:

  package { 'mysql':
    provider => gem,
  }

  package { 'mysql-opt':
    name     => 'mysql',
    provider => gem,
    command  => '/opt/ruby/bin/gem',
  }

Each provider defines a package management command and uses the first
instance of the command found in the PATH.

Providers supporting the targetable feature allow you to specify the
absolute path of the package management command. Specifying the absolute
path is useful when multiple instances of the command are installed, or
the command is not in the PATH.

Default: `default`

Requires features targetable.

([↑ Back to package attributes](#package-attributes))


#### name {#package-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The package name.  This is the name that the packaging
system uses internally, which is sometimes (especially on Solaris)
a name that is basically useless to humans.  If a package goes by
several names, you can use a single title and then set the name
conditionally:

    # In the 'openssl' class
    $ssl = $os['name'] ? {
      solaris => SMCossl,
      default => openssl
    }

    package { 'openssl':
      ensure => installed,
      name   => $ssl,
    }

    ...

    $ssh = $os['name'] ? {
      solaris => SMCossh,
      default => openssh
    }

    package { 'openssh':
      ensure  => installed,
      name    => $ssh,
      require => Package['openssl'],
    }

([↑ Back to package attributes](#package-attributes))


#### ensure {#package-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

What state the package should be in. On packaging systems that can
retrieve new packages on their own, you can choose which package to
retrieve by specifying a version number or `latest` as the ensure
value. On packaging systems that manage configuration files separately
from "normal" system files, you can uninstall config files by
specifying `purged` as the ensure value. This defaults to `installed`.

Version numbers must match the full version to install, including
release if the provider uses a release moniker. For
example, to install the bash package from the rpm
`bash-4.1.2-29.el6.x86_64.rpm`, use the string `'4.1.2-29.el6'`.

On supported providers, version ranges can also be ensured. For example,
inequalities: `<2.0.0`, or intersections: `>1.0.0 <2.0.0`.

Default: `installed`

Allowed values:

* `present`
* `absent`
* `purged`
* `disabled`
* `installed`
* `latest`
* `/./`

([↑ Back to package attributes](#package-attributes))


#### adminfile {#package-attribute-adminfile}

A file containing package defaults for installing packages.

This attribute is only used on Solaris. Its value should be a path to a
local file stored on the target system. Solaris's package tools expect
either an absolute file path or a relative path to a file in
`/var/sadm/install/admin`.

The value of `adminfile` will be passed directly to the `pkgadd` or
`pkgrm` command with the `-a <ADMINFILE>` option.

([↑ Back to package attributes](#package-attributes))


#### allow_virtual {#package-attribute-allow_virtual}

Specifies if virtual package names are allowed for install and uninstall.

Allowed values:

* `true`
* `false`
* `yes`
* `no`

Requires features virtual_packages.

([↑ Back to package attributes](#package-attributes))


#### allowcdrom {#package-attribute-allowcdrom}

Tells apt to allow cdrom sources in the sources.list file.
Normally apt will bail if you try this.

Allowed values:

* `true`
* `false`

([↑ Back to package attributes](#package-attributes))


#### category {#package-attribute-category}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### configfiles {#package-attribute-configfiles}

Whether to keep or replace modified config files when installing or
upgrading a package. This only affects the `apt` and `dpkg` providers.

Default: `keep`

Allowed values:

* `keep`
* `replace`

([↑ Back to package attributes](#package-attributes))


#### description {#package-attribute-description}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### enable_only {#package-attribute-enable_only}

Tells `dnf module` to only enable a specific module, instead
of installing its default profile.

Modules with no default profile will be enabled automatically
without the use of this parameter.

Conflicts with the `flavor` property, which selects a profile
to install.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

([↑ Back to package attributes](#package-attributes))


#### flavor {#package-attribute-flavor}

_(**Property:** This attribute represents concrete state on the target system.)_

OpenBSD and DNF modules support 'flavors', which are
further specifications for which type of package you want.

Requires features supports_flavors.

([↑ Back to package attributes](#package-attributes))


#### install_only {#package-attribute-install_only}

It should be set for packages that should only ever be installed,
never updated. Kernels in particular fall into this category.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

Requires features install_only.

([↑ Back to package attributes](#package-attributes))


#### install_options {#package-attribute-install_options}

An array of additional options to pass when installing a package. These
options are package-specific, and should be documented by the software
vendor.  One commonly implemented option is `INSTALLDIR`:

    package { 'mysql':
      ensure          => installed,
      source          => 'N:/packages/mysql-5.5.16-winx64.msi',
      install_options => [ '/S', { 'INSTALLDIR' => 'C:\\mysql-5.5' } ],
    }

Each option in the array can either be a string or a hash, where each
key and value pair are interpreted in a provider specific way.  Each
option will automatically be quoted when passed to the install command.

With Windows packages, note that file paths in an install option must
use backslashes. (Since install options are passed directly to the
installation command, forward slashes won't be automatically converted
like they are in `file` resources.) Note also that backslashes in
double-quoted strings _must_ be escaped and backslashes in single-quoted
strings _can_ be escaped.

Requires features install_options.

([↑ Back to package attributes](#package-attributes))


#### instance {#package-attribute-instance}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### mark {#package-attribute-mark}

_(**Property:** This attribute represents concrete state on the target system.)_

Set to hold to tell Debian apt/Solaris pkg to hold the package version

#{mark_doc}
Default is "none". Mark can be specified with or without `ensure`,
if `ensure` is missing will default to "present".

Mark cannot be specified together with "purged", or "absent"
values for `ensure`.

Allowed values:

* `hold`
* `none`

Requires features holdable.

([↑ Back to package attributes](#package-attributes))


#### package_settings {#package-attribute-package_settings}

_(**Property:** This attribute represents concrete state on the target system.)_

Settings that can change the contents or configuration of a package.

The formatting and effects of package_settings are provider-specific; any
provider that implements them must explain how to use them in its
documentation. (Our general expectation is that if a package is
installed but its settings are out of sync, the provider should
re-install that package with the desired settings.)

An example of how package_settings could be used is FreeBSD's port build
options --- a future version of the provider could accept a hash of options,
and would reinstall the port if the installed version lacked the correct
settings.

    package { 'www/apache22':
      package_settings => { 'SUEXEC' => false }
    }

Again, check the documentation of your platform's package provider to see
the actual usage.

Requires features package_settings.

([↑ Back to package attributes](#package-attributes))


#### platform {#package-attribute-platform}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### provider {#package-attribute-provider}

The specific backend to use for this `package` resource. You will seldom need to specify this --- Puppet will usually discover the appropriate provider for your platform.

Available providers are:

* [`aix`](#package-provider-aix)
* [`appdmg`](#package-provider-appdmg)
* [`apple`](#package-provider-apple)
* [`apt`](#package-provider-apt)
* [`aptitude`](#package-provider-aptitude)
* [`aptrpm`](#package-provider-aptrpm)
* [`blastwave`](#package-provider-blastwave)
* [`dnf`](#package-provider-dnf)
* [`dnfmodule`](#package-provider-dnfmodule)
* [`dpkg`](#package-provider-dpkg)
* [`fink`](#package-provider-fink)
* [`freebsd`](#package-provider-freebsd)
* [`gem`](#package-provider-gem)
* [`hpux`](#package-provider-hpux)
* [`macports`](#package-provider-macports)
* [`nim`](#package-provider-nim)
* [`openbsd`](#package-provider-openbsd)
* [`opkg`](#package-provider-opkg)
* [`pacman`](#package-provider-pacman)
* [`pip2`](#package-provider-pip2)
* [`pip3`](#package-provider-pip3)
* [`pip`](#package-provider-pip)
* [`pkg`](#package-provider-pkg)
* [`pkgdmg`](#package-provider-pkgdmg)
* [`pkgin`](#package-provider-pkgin)
* [`pkgng`](#package-provider-pkgng)
* [`pkgutil`](#package-provider-pkgutil)
* [`portage`](#package-provider-portage)
* [`ports`](#package-provider-ports)
* [`portupgrade`](#package-provider-portupgrade)
* [`puppet_gem`](#package-provider-puppet_gem)
* [`puppetserver_gem`](#package-provider-puppetserver_gem)
* [`rpm`](#package-provider-rpm)
* [`rug`](#package-provider-rug)
* [`sun`](#package-provider-sun)
* [`sunfreeware`](#package-provider-sunfreeware)
* [`tdnf`](#package-provider-tdnf)
* [`up2date`](#package-provider-up2date)
* [`urpmi`](#package-provider-urpmi)
* [`windows`](#package-provider-windows)
* [`xbps`](#package-provider-xbps)
* [`yum`](#package-provider-yum)
* [`zypper`](#package-provider-zypper)

([↑ Back to package attributes](#package-attributes))


#### reinstall_on_refresh {#package-attribute-reinstall_on_refresh}

Whether this resource should respond to refresh events (via `subscribe`,
`notify`, or the `~>` arrow) by reinstalling the package. Only works for
providers that support the `reinstallable` feature.

This is useful for source-based distributions, where you may want to
recompile a package if the build options change.

If you use this, be careful of notifying classes when you want to restart
services. If the class also contains a refreshable package, doing so could
cause unnecessary re-installs.

Default: `false`

Allowed values:

* `true`
* `false`

([↑ Back to package attributes](#package-attributes))


#### responsefile {#package-attribute-responsefile}

A file containing any necessary answers to questions asked by
the package.  This is currently used on Solaris and Debian.  The
value will be validated according to system rules, but it should
generally be a fully qualified path.

([↑ Back to package attributes](#package-attributes))


#### root {#package-attribute-root}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### source {#package-attribute-source}

Where to find the package file. This is mostly used by providers that don't
automatically download packages from a central repository. (For example:
the `yum` provider ignores this attribute, `apt` provider uses it if present
and the `rpm` and `dpkg` providers require it.)

Different providers accept different values for `source`. Most providers
accept paths to local files stored on the target system. Some providers
may also accept URLs or network drive paths. Puppet will not
automatically retrieve source files for you, and usually just passes the
value of `source` to the package installation command.

You can use a `file` resource if you need to manually copy package files
to the target system.

([↑ Back to package attributes](#package-attributes))


#### status {#package-attribute-status}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### uninstall_options {#package-attribute-uninstall_options}

An array of additional options to pass when uninstalling a package. These
options are package-specific, and should be documented by the software
vendor.  For example:

    package { 'VMware Tools':
      ensure            => absent,
      uninstall_options => [ { 'REMOVE' => 'Sync,VSS' } ],
    }

Each option in the array can either be a string or a hash, where each
key and value pair are interpreted in a provider specific way.  Each
option will automatically be quoted when passed to the uninstall
command.

On Windows, this is the **only** place in Puppet where backslash
separators should be used.  Note that backslashes in double-quoted
strings _must_ be double-escaped and backslashes in single-quoted
strings _may_ be double-escaped.

Requires features uninstall_options.

([↑ Back to package attributes](#package-attributes))


#### vendor {#package-attribute-vendor}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


### Providers {#package-providers}

#### aix {#package-provider-aix}

Installation from an AIX software directory, using the AIX `installp`
command.  The `source` parameter is required for this provider, and should
be set to the absolute path (on the puppet agent machine) of a directory
containing one or more BFF package files.

The `installp` command will generate a table of contents file (named `.toc`)
in this directory, and the `name` parameter (or resource title) that you
specify for your `package` resource must match a package name that exists
in the `.toc` file.

Note that package downgrades are *not* supported; if your resource specifies
a specific version number and there is already a newer version of the package
installed on the machine, the resource will fail with an error message.

* Required binaries: `/usr/bin/lslpp`, `/usr/sbin/installp`
* Confined to: `os.name == [:aix]`
* Default for: `["os.name", "aix"] == `
* Supported features: `versionable`

#### appdmg {#package-provider-appdmg}

Package management which copies application bundles to a target.

* Required binaries: `/usr/bin/curl`, `/usr/bin/ditto`, `/usr/bin/hdiutil`
* Confined to: `os.name == darwin`, `feature == cfpropertylist`

#### apple {#package-provider-apple}

Package management based on OS X's built-in packaging system.  This is
essentially the simplest and least functional package system in existence --
it only supports installation; no deletion or upgrades.  The provider will
automatically add the `.pkg` extension, so leave that off when specifying
the package name.

* Required binaries: `/usr/sbin/installer`
* Confined to: `os.name == darwin`

#### apt {#package-provider-apt}

Package management via `apt-get`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to apt-get.
These options should be specified as an array where each element is either a
 string or a hash.

* Required binaries: `/usr/bin/apt-cache`, `/usr/bin/apt-get`, `/usr/bin/apt-mark`, `/usr/bin/debconf-set-selections`
* Default for: `["os.family", "debian"] == `
* Supported features: `install_options`, `version_ranges`, `versionable`, `virtual_packages`

#### aptitude {#package-provider-aptitude}

Package management via `aptitude`.

* Required binaries: `/usr/bin/apt-cache`, `/usr/bin/aptitude`
* Supported features: `versionable`

#### aptrpm {#package-provider-aptrpm}

Package management via `apt-get` ported to `rpm`.

* Required binaries: `apt-cache`, `apt-get`, `rpm`
* Supported features: `versionable`

#### blastwave {#package-provider-blastwave}

Package management using Blastwave.org's `pkg-get` command on Solaris.

* Required binaries: `pkgget`
* Confined to: `os.family == solaris`

#### dnf {#package-provider-dnf}

Support via `dnf`.

Using this provider's `uninstallable` feature will not remove dependent packages. To
remove dependent packages with this provider use the `purgeable` feature, but note this
feature is destructive and should be used with the utmost care.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to dnf.
These options should be specified as an array where each element is either
 a string or a hash.

* Required binaries: `dnf`, `rpm`
* Default for: `["os.name", "fedora"] == `, `["os.family", "redhat"] == `, `["os.name", "amazon"] == ["os.release.major", "[\"2023\"]"]`
* Supported features: `install_only`, `install_options`, `version_ranges`, `versionable`, `virtual_packages`

#### dnfmodule {#package-provider-dnfmodule}



* Required binaries: `/usr/bin/dnf`
* Supported features: `disableable`, `installable`, `supports_flavors`, `uninstallable`, `versionable`

#### dpkg {#package-provider-dpkg}

Package management via `dpkg`.  Because this only uses `dpkg`
and not `apt`, you must specify the source of any packages you want
to manage.

* Required binaries: `/usr/bin/dpkg`, `/usr/bin/dpkg-deb`, `/usr/bin/dpkg-query`
* Supported features: `holdable`, `virtual_packages`

#### fink {#package-provider-fink}

Package management via `fink`.

* Required binaries: `/sw/bin/apt-cache`, `/sw/bin/apt-get`, `/sw/bin/dpkg-query`, `/sw/bin/fink`
* Supported features: `versionable`

#### freebsd {#package-provider-freebsd}

The specific form of package management on FreeBSD.  This is an
extremely quirky packaging system, in that it freely mixes between
ports and packages.  Apparently all of the tools are written in Ruby,
so there are plans to rewrite this support to directly use those
libraries.

* Required binaries: `/usr/sbin/pkg_add`, `/usr/sbin/pkg_delete`, `/usr/sbin/pkg_info`
* Confined to: `os.name == freebsd`

#### gem {#package-provider-gem}

Ruby Gem support. If a URL is passed via `source`, then that URL is
appended to the list of remote gem repositories; to ensure that only the
specified source is used, also pass `--clear-sources` via `install_options`.
If source is present but is not a valid URL, it will be interpreted as the
path to a local gem file. If source is not present, the gem will be
installed from the default gem repositories. Note that to modify this for Windows, it has to be a valid URL.

This provider supports the `install_options` and `uninstall_options` attributes,
which allow command-line flags to be passed to the gem command.
These options should be specified as an array where each element is either a
string or a hash.
* Supported features: `install_options`, `targetable`, `uninstall_options`, `version_ranges`, `versionable`

#### hpux {#package-provider-hpux}

HP-UX's packaging system.

* Required binaries: `/usr/sbin/swinstall`, `/usr/sbin/swlist`, `/usr/sbin/swremove`
* Confined to: `os.name == hp-ux`
* Default for: `["os.name", "hp-ux"] == `

#### macports {#package-provider-macports}

Package management using MacPorts on OS X.

Supports MacPorts versions and revisions, but not variants.
Variant preferences may be specified using
[the MacPorts variants.conf file](http://guide.macports.org/chunked/internals.configuration-files.html#internals.configuration-files.variants-conf).

When specifying a version in the Puppet DSL, only specify the version, not the revision.
Revisions are only used internally for ensuring the latest version/revision of a port.

* Confined to: `os.name == darwin`
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`

#### nim {#package-provider-nim}

Installation from an AIX NIM LPP source.  The `source` parameter is required
for this provider, and should specify the name of a NIM `lpp_source` resource
that is visible to the puppet agent machine.  This provider supports the
management of both BFF/installp and RPM packages.

Note that package downgrades are *not* supported; if your resource specifies
a specific version number and there is already a newer version of the package
installed on the machine, the resource will fail with an error message.

* Required binaries: `/usr/bin/lslpp`, `/usr/sbin/nimclient`, `rpm`
* Confined to: `exists == /etc/niminfo`
* Supported features: `versionable`

#### openbsd {#package-provider-openbsd}

OpenBSD's form of `pkg_add` support.

This provider supports the `install_options` and `uninstall_options`
attributes, which allow command-line flags to be passed to pkg_add and pkg_delete.
These options should be specified as an array where each element is either a
 string or a hash.

* Required binaries: `pkg_add`, `pkg_delete`, `pkg_info`
* Confined to: `os.name == openbsd`
* Default for: `["os.name", "openbsd"] == `
* Supported features: `install_options`, `supports_flavors`, `uninstall_options`, `upgradeable`, `versionable`

#### opkg {#package-provider-opkg}

Opkg packaging support. Common on OpenWrt and OpenEmbedded platforms

* Required binaries: `opkg`
* Confined to: `os.name == openwrt`
* Default for: `["os.name", "openwrt"] == `

#### pacman {#package-provider-pacman}

Support for the Package Manager Utility (pacman) used in Archlinux.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pacman.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `/usr/bin/pacman`
* Confined to: `os.name == [:archlinux, :manjarolinux, :artix]`
* Default for: `["os.name", "[:archlinux, :manjarolinux, :artix]"] == `
* Supported features: `install_options`, `purgeable`, `uninstall_options`, `upgradeable`, `virtual_packages`

#### pip {#package-provider-pip}

Python packages via `pip`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip.
These options should be specified as an array where each element is either a string or a hash.
* Supported features: `install_options`, `installable`, `targetable`, `uninstallable`, `upgradeable`, `version_ranges`, `versionable`

#### pip2 {#package-provider-pip2}

Python packages via `pip2`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip2.
These options should be specified as an array where each element is either a string or a hash.
* Supported features: `install_options`, `installable`, `targetable`, `uninstallable`, `upgradeable`, `versionable`

#### pip3 {#package-provider-pip3}

Python packages via `pip3`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip3.
These options should be specified as an array where each element is either a string or a hash.
* Supported features: `install_options`, `installable`, `targetable`, `uninstallable`, `upgradeable`, `versionable`

#### pkg {#package-provider-pkg}

OpenSolaris image packaging system. See pkg(5) for more information.

This provider supports the `install_options` attribute, which allows
command-line flags to be passed to pkg. These options should be specified as an
array where each element is either a string or a hash.

* Required binaries: `/usr/bin/pkg`
* Confined to: `os.family == solaris`
* Default for: `["os.family", "solaris"] == ["kernelrelease", "['5.11', '5.12']"]`
* Supported features: `holdable`, `install_options`, `upgradable`, `versionable`

#### pkgdmg {#package-provider-pkgdmg}

Package management based on Apple's Installer.app and DiskUtility.app.

This provider works by checking the contents of a DMG image for Apple pkg or
mpkg files. Any number of pkg or mpkg files may exist in the root directory
of the DMG file system, and Puppet will install all of them. Subdirectories
are not checked for packages.

This provider can also accept plain .pkg (but not .mpkg) files in addition
to .dmg files.

Notes:

* The `source` attribute is mandatory. It must be either a local disk path
  or an HTTP, HTTPS, or FTP URL to the package.
* The `name` of the resource must be the filename (without path) of the DMG file.
* When installing the packages from a DMG, this provider writes a file to
  disk at `/var/db/.puppet_pkgdmg_installed_NAME`. If that file is present,
  Puppet assumes all packages from that DMG are already installed.
* This provider is not versionable and uses DMG filenames to determine
  whether a package has been installed. Thus, to install new a version of a
  package, you must create a new DMG with a different filename.

* Required binaries: `/usr/bin/curl`, `/usr/bin/hdiutil`, `/usr/sbin/installer`
* Confined to: `os.name == darwin`, `feature == cfpropertylist`
* Default for: `["os.name", "darwin"] == `

#### pkgin {#package-provider-pkgin}

Package management using pkgin, a binary package manager for pkgsrc.

* Required binaries: `pkgin`
* Default for: `["os.name", "[:smartos, :netbsd]"] == `
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`

#### pkgng {#package-provider-pkgng}

A PkgNG provider for FreeBSD and DragonFly.

* Required binaries: `/usr/local/sbin/pkg`
* Confined to: `os.name == [:freebsd, :dragonfly]`
* Default for: `["os.name", "[:freebsd, :dragonfly]"] == `
* Supported features: `install_options`, `upgradeable`, `versionable`

#### pkgutil {#package-provider-pkgutil}

Package management using Peter Bonivart's ``pkgutil`` command on Solaris.

* Confined to: `os.family == solaris`

#### portage {#package-provider-portage}

Provides packaging support for Gentoo's portage system.

This provider supports the `install_options` and `uninstall_options` attributes, which allows command-line
flags to be passed to emerge. These options should be specified as an array where each element is either a string or a hash.

* Confined to: `os.family == gentoo`
* Default for: `["os.family", "gentoo"] == `
* Supported features: `install_options`, `purgeable`, `reinstallable`, `uninstall_options`, `versionable`, `virtual_packages`

#### ports {#package-provider-ports}

Support for FreeBSD's ports.  Note that this, too, mixes packages and ports.

* Required binaries: `/usr/local/sbin/pkg_deinstall`, `/usr/local/sbin/portupgrade`, `/usr/local/sbin/portversion`, `/usr/sbin/pkg_info`

#### portupgrade {#package-provider-portupgrade}

Support for FreeBSD's ports using the portupgrade ports management software.
Use the port's full origin as the resource name. eg (ports-mgmt/portupgrade)
for the portupgrade port.

* Required binaries: `/usr/local/sbin/pkg_deinstall`, `/usr/local/sbin/portinstall`, `/usr/local/sbin/portupgrade`, `/usr/local/sbin/portversion`, `/usr/sbin/pkg_info`

#### puppet_gem {#package-provider-puppet_gem}

Puppet Ruby Gem support. This provider is useful for managing
gems needed by the ruby provided in the puppet-agent package.

* Required binaries: `Puppet.run_mode.gem_cmd`
* Confined to: `true == Puppet.runtime[:facter].value(:aio_agent_version)`
* Supported features: `install_options`, `uninstall_options`, `versionable`

#### puppetserver_gem {#package-provider-puppetserver_gem}

Puppet Server Ruby Gem support. If a URL is passed via `source`, then
that URL is appended to the list of remote gem repositories which by default
contains rubygems.org; To ensure that only the specified source is used also
pass `--clear-sources` in via `install_options`; if a source is present but
is not a valid URL, it will be interpreted as the path to a local gem file.
If source is not present at all, the gem will be installed from the default
gem repositories.

* Confined to: `feature == hocon`, `fips_enabled == false`
* Supported features: `install_options`, `uninstall_options`, `versionable`

#### rpm {#package-provider-rpm}

RPM packaging support; should work anywhere with a working `rpm`
binary.

This provider supports the `install_options` and `uninstall_options`
attributes, which allow command-line flags to be passed to rpm.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `rpm`
* Supported features: `install_only`, `install_options`, `uninstall_options`, `versionable`, `virtual_packages`

#### rug {#package-provider-rug}

Support for suse `rug` package manager.

* Required binaries: `/usr/bin/rug`, `rpm`
* Confined to: `os.name == [:suse, :sles]`
* Supported features: `versionable`

#### sun {#package-provider-sun}

Sun's packaging system.  Requires that you specify the source for
the packages you're managing.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pkgadd.
These options should be specified as an array where each element is either a string
 or a hash.

* Required binaries: `/usr/bin/pkginfo`, `/usr/sbin/pkgadd`, `/usr/sbin/pkgrm`
* Confined to: `os.family == solaris`
* Default for: `["os.family", "solaris"] == `
* Supported features: `install_options`

#### sunfreeware {#package-provider-sunfreeware}

Package management using sunfreeware.com's `pkg-get` command on Solaris.
At this point, support is exactly the same as `blastwave` support and
has not actually been tested.

* Required binaries: `pkg-get`
* Confined to: `os.family == solaris`

#### tdnf {#package-provider-tdnf}

Support via `tdnf`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to tdnf.
These options should be spcified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}), or an
array where each element is either a string or a hash.

* Required binaries: `rpm`, `tdnf`
* Default for: `["os.name", "PhotonOS"] == `
* Supported features: `install_options`, `versionable`, `virtual_packages`

#### up2date {#package-provider-up2date}

Support for Red Hat's proprietary `up2date` package update
mechanism.

* Required binaries: `/usr/sbin/up2date-nox`
* Confined to: `os.family == redhat`
* Default for: `["os.family", "redhat"] == ["os.distro.release.full", "[\"2.1\", \"3\", \"4\"]"]`

#### urpmi {#package-provider-urpmi}

Support via `urpmi`.

* Required binaries: `rpm`, `urpme`, `urpmi`, `urpmq`
* Default for: `["os.name", "[:mandriva, :mandrake]"] == `
* Supported features: `versionable`

#### windows {#package-provider-windows}

Windows package management.

This provider supports either MSI or self-extracting executable installers.

This provider requires a `source` attribute when installing the package.
It accepts paths to local files, mapped drives, or UNC paths.

This provider supports the `install_options` and `uninstall_options`
attributes, which allow command-line flags to be passed to the installer.
These options should be specified as an array where each element is either
a string or a hash.

If the executable requires special arguments to perform a silent install or
uninstall, then the appropriate arguments should be specified using the
`install_options` or `uninstall_options` attributes, respectively.  Puppet
will automatically quote any option that contains spaces.

* Confined to: `os.name == windows`
* Default for: `["os.name", "windows"] == `
* Supported features: `install_options`, `installable`, `uninstall_options`, `uninstallable`, `versionable`

#### xbps {#package-provider-xbps}

Support for the Package Manager Utility (xbps) used in VoidLinux.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to xbps-install.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `/usr/bin/xbps-install`, `/usr/bin/xbps-pkgdb`, `/usr/bin/xbps-query`, `/usr/bin/xbps-remove`
* Confined to: `os.name == void`
* Default for: `["os.name", "void"] == `
* Supported features: `holdable`, `install_options`, `uninstall_options`, `upgradeable`, `virtual_packages`

#### yum {#package-provider-yum}

Support via `yum`.

Using this provider's `uninstallable` feature will not remove dependent packages. To
remove dependent packages with this provider use the `purgeable` feature, but note this
feature is destructive and should be used with the utmost care.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to yum.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `rpm`, `yum`
* Default for: `["os.name", "amazon"] == `, `["os.family", "redhat"] == ["os.release.major", "(4..7).to_a"]`
* Supported features: `install_only`, `install_options`, `version_ranges`, `versionable`, `virtual_packages`

#### zypper {#package-provider-zypper}

Support for SuSE `zypper` package manager. Found in SLES10sp2+ and SLES11.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to zypper.
These options should be specified as an array where each element is either a
string or a hash.

* Required binaries: `/usr/bin/zypper`
* Confined to: `os.name == [:suse, :sles, :sled, :opensuse]`
* Default for: `["os.name", "[:suse, :sles, :sled, :opensuse]"] == `
* Supported features: `install_options`, `versionable`, `virtual_packages`

### Provider Features {#package-provider-features}

Available features:

* `disableable` --- The provider can disable packages. This feature is used by specifying `disabled` as the desired value for the package.
* `holdable` --- The provider is capable of placing packages on hold such that they are not automatically upgraded as a result of other package dependencies unless explicit action is taken by a user or another package.
* `install_only` --- The provider accepts options to only install packages never update (kernels, etc.)
* `install_options` --- The provider accepts options to be passed to the installer command.
* `installable` --- The provider can install packages.
* `package_settings` --- The provider accepts package_settings to be ensured for the given package. The meaning and format of these settings is provider-specific.
* `purgeable` --- The provider can purge packages.  This generally means that all traces of the package are removed, including existing configuration files.  This feature is thus destructive and should be used with the utmost care.
* `reinstallable` --- The provider can reinstall packages.
* `supports_flavors` --- The provider accepts flavors, which are specific variants of packages.
* `targetable` --- The provider accepts a targeted package management command.
* `uninstall_options` --- The provider accepts options to be passed to the uninstaller command.
* `uninstallable` --- The provider can uninstall packages.
* `upgradeable` --- The provider can upgrade to the latest version of a package.  This feature is used by specifying `latest` as the desired value for the package.
* `version_ranges` --- The provider can ensure version ranges.
* `versionable` --- The provider is capable of interrogating the package database for installed version(s), and can select which out of a set of available versions of a package to install if asked.
* `virtual_packages` --- The provider accepts virtual package names for install and uninstall.

Provider support:

* **aix** - _versionable_
* **appdmg** - No supported Provider features
* **apple** - No supported Provider features
* **apt** - _versionable, install options, virtual packages, version ranges_
* **aptitude** - _versionable_
* **aptrpm** - _versionable_
* **blastwave** - No supported Provider features
* **dnf** - _install options, versionable, virtual packages, install only, version ranges_
* **dnfmodule** - _installable, uninstallable, versionable, supports flavors, disableable_
* **dpkg** - _holdable, virtual packages_
* **fink** - _versionable_
* **freebsd** - No supported Provider features
* **gem** - _versionable, install options, uninstall options, targetable, version ranges_
* **hpux** - No supported Provider features
* **macports** - _installable, uninstallable, upgradeable, versionable_
* **nim** - _versionable_
* **openbsd** - _versionable, install options, uninstall options, upgradeable, supports flavors_
* **opkg** - No supported Provider features
* **pacman** - _install options, uninstall options, upgradeable, virtual packages, purgeable_
* **pip** - _installable, uninstallable, upgradeable, versionable, version ranges, install options, targetable_
* **pip2** - _installable, uninstallable, upgradeable, versionable, install options, targetable_
* **pip3** - _installable, uninstallable, upgradeable, versionable, install options, targetable_
* **pkg** - _versionable, upgradable, holdable, install options_
* **pkgdmg** - No supported Provider features
* **pkgin** - _installable, uninstallable, upgradeable, versionable_
* **pkgng** - _versionable, upgradeable, install options_
* **pkgutil** - No supported Provider features
* **portage** - _install options, purgeable, reinstallable, uninstall options, versionable, virtual packages_
* **ports** - No supported Provider features
* **portupgrade** - No supported Provider features
* **puppet_gem** - _versionable, install options, uninstall options_
* **puppetserver_gem** - _versionable, install options, uninstall options_
* **rpm** - _versionable, install options, uninstall options, virtual packages, install only_
* **rug** - _versionable_
* **sun** - _install options_
* **sunfreeware** - No supported Provider features
* **tdnf** - _install options, versionable, virtual packages_
* **up2date** - No supported Provider features
* **urpmi** - _versionable_
* **windows** - _installable, uninstallable, install options, uninstall options, versionable_
* **xbps** - _install options, uninstall options, upgradeable, holdable, virtual packages_
* **yum** - _install options, versionable, virtual packages, install only, version ranges_
* **zypper** - _versionable, install options, virtual packages_
  




