---
layout: default
built_from_commit: a0909f4eae7490d52cb1e7dc81010592ba607679
title: 'Resource Type: group'
canonical: "/puppet/latest/types/group.html"
---

# Resource Type: group

> **NOTE:** This page was generated from the Puppet source code on 2024-11-04 23:38:25 +0000



## group

* [Attributes](#group-attributes)
* [Providers](#group-providers)
* [Provider Features](#group-provider-features)

### Description {#group-description}

Manage groups. On most platforms this can only create groups.
Group membership must be managed on individual users.

On some platforms such as OS X, group membership is managed as an
attribute of the group, not the user record. Providers must have
the feature 'manages_members' to manage the 'members' property of
a group record.

### Attributes {#group-attributes}

<pre><code>group { 'resource title':
  <a href="#group-attribute-name">name</a>                 =&gt; <em># <strong>(namevar)</strong> The group name. While naming limitations vary by </em>
  <a href="#group-attribute-ensure">ensure</a>               =&gt; <em># Create or remove the group.  Default: `present`  </em>
  <a href="#group-attribute-allowdupe">allowdupe</a>            =&gt; <em># Whether to allow duplicate GIDs.  Default...</em>
  <a href="#group-attribute-attribute_membership">attribute_membership</a> =&gt; <em># AIX only. Configures the behavior of the...</em>
  <a href="#group-attribute-attributes">attributes</a>           =&gt; <em># Specify group AIX attributes, as an array of...</em>
  <a href="#group-attribute-auth_membership">auth_membership</a>      =&gt; <em># Configures the behavior of the `members...</em>
  <a href="#group-attribute-forcelocal">forcelocal</a>           =&gt; <em># Forces the management of local accounts when...</em>
  <a href="#group-attribute-gid">gid</a>                  =&gt; <em># The group ID.  Must be specified numerically....</em>
  <a href="#group-attribute-ia_load_module">ia_load_module</a>       =&gt; <em># The name of the I&A module to use to manage this </em>
  <a href="#group-attribute-members">members</a>              =&gt; <em># The members of the group. For platforms or...</em>
  <a href="#group-attribute-provider">provider</a>             =&gt; <em># The specific backend to use for this `group...</em>
  <a href="#group-attribute-system">system</a>               =&gt; <em># Whether the group is a system group with lower...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#group-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The group name. While naming limitations vary by operating system,
it is advisable to restrict names to the lowest common denominator,
which is a maximum of 8 characters beginning with a letter.

Note that Puppet considers group names to be case-sensitive, regardless
of the platform's own rules; be sure to always use the same case when
referring to a given group.

([↑ Back to group attributes](#group-attributes))


#### ensure {#group-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

Create or remove the group.

Default: `present`

Allowed values:

* `present`
* `absent`

([↑ Back to group attributes](#group-attributes))


#### allowdupe {#group-attribute-allowdupe}

Whether to allow duplicate GIDs.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

([↑ Back to group attributes](#group-attributes))


#### attribute_membership {#group-attribute-attribute_membership}

AIX only. Configures the behavior of the `attributes` parameter.

* `minimum` (default) --- The provided list of attributes is partial, and Puppet
  **ignores** any attributes that aren't listed there.
* `inclusive` --- The provided list of attributes is comprehensive, and
  Puppet **purges** any attributes that aren't listed there.

Default: `minimum`

Allowed values:

* `inclusive`
* `minimum`

([↑ Back to group attributes](#group-attributes))


#### attributes {#group-attribute-attributes}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify group AIX attributes, as an array of `'key=value'` strings. This
parameter's behavior can be configured with `attribute_membership`.

Requires features manages_aix_lam.

([↑ Back to group attributes](#group-attributes))


#### auth_membership {#group-attribute-auth_membership}

Configures the behavior of the `members` parameter.

* `false` (default) --- The provided list of group members is partial,
  and Puppet **ignores** any members that aren't listed there.
* `true` --- The provided list of of group members is comprehensive, and
  Puppet **purges** any members that aren't listed there.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

([↑ Back to group attributes](#group-attributes))


#### forcelocal {#group-attribute-forcelocal}

Forces the management of local accounts when accounts are also
being managed by some other Name Switch Service (NSS). For AIX, refer to the `ia_load_module` parameter.

This option relies on your operating system's implementation of `luser*` commands, such as `luseradd` , `lgroupadd`, and `lusermod`. The `forcelocal` option could behave unpredictably in some circumstances. If the tools it depends on are not available, it might have no effect at all.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

Requires features manages_local_users_and_groups.

([↑ Back to group attributes](#group-attributes))


#### gid {#group-attribute-gid}

_(**Property:** This attribute represents concrete state on the target system.)_

The group ID.  Must be specified numerically.  If no group ID is
specified when creating a new group, then one will be chosen
automatically according to local system standards. This will likely
result in the same group having different GIDs on different systems,
which is not recommended.

On Windows, this property is read-only and will return the group's security
identifier (SID).

([↑ Back to group attributes](#group-attributes))


#### ia_load_module {#group-attribute-ia_load_module}

The name of the I&A module to use to manage this group.
This should be set to `files` if managing local groups.

Requires features manages_aix_lam.

([↑ Back to group attributes](#group-attributes))


#### members {#group-attribute-members}

_(**Property:** This attribute represents concrete state on the target system.)_

The members of the group. For platforms or directory services where group
membership is stored in the group objects, not the users. This parameter's
behavior can be configured with `auth_membership`.

Requires features manages_members.

([↑ Back to group attributes](#group-attributes))


#### provider {#group-attribute-provider}

The specific backend to use for this `group` resource. You will seldom need to specify this --- Puppet will usually discover the appropriate provider for your platform.

Available providers are:

* [`aix`](#group-provider-aix)
* [`directoryservice`](#group-provider-directoryservice)
* [`groupadd`](#group-provider-groupadd)
* [`ldap`](#group-provider-ldap)
* [`pw`](#group-provider-pw)
* [`windows_adsi`](#group-provider-windows_adsi)

([↑ Back to group attributes](#group-attributes))


#### system {#group-attribute-system}

Whether the group is a system group with lower GID.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

([↑ Back to group attributes](#group-attributes))


### Providers {#group-providers}

#### aix {#group-provider-aix}

Group management for AIX.

* Required binaries: `/usr/bin/chgroup`, `/usr/bin/mkgroup`, `/usr/sbin/lsgroup`, `/usr/sbin/rmgroup`
* Confined to: `os.name == aix`
* Default for: `["os.name", "aix"] == `
* Supported features: `manages_aix_lam`, `manages_local_users_and_groups`, `manages_members`

#### directoryservice {#group-provider-directoryservice}

Group management using DirectoryService on OS X.

* Required binaries: `/usr/bin/dscl`
* Confined to: `os.name == darwin`
* Default for: `["os.name", "darwin"] == `
* Supported features: `manages_members`

#### groupadd {#group-provider-groupadd}

Group management via `groupadd` and its ilk. The default for most platforms.

To use the `forcelocal` parameter, you need to install the `libuser` package (providing
 `/usr/sbin/lgroupadd` and `/usr/sbin/luseradd`).

* Required binaries: `groupadd`, `groupdel`, `groupmod`

#### ldap {#group-provider-ldap}

Group management via LDAP.

This provider requires that you have valid values for all of the
LDAP-related settings in `puppet.conf`, including `ldapbase`.  You will
almost definitely need settings for `ldapuser` and `ldappassword` in order
for your clients to write to LDAP.

Note that this provider will automatically generate a GID for you if you do
not specify one, but it is a potentially expensive operation, as it
iterates across all existing groups to pick the appropriate next one.

* Confined to: `feature == ldap`, `false == (Puppet[:ldapuser] == "")`

#### pw {#group-provider-pw}

Group management via `pw` on FreeBSD and DragonFly BSD.

* Required binaries: `pw`
* Confined to: `os.name == [:freebsd, :dragonfly]`
* Default for: `["os.name", "[:freebsd, :dragonfly]"] == `
* Supported features: `manages_members`

#### windows_adsi {#group-provider-windows_adsi}

Local group management for Windows. Group members can be both users and groups.
Additionally, local groups can contain domain users.

* Confined to: `os.name == windows`
* Default for: `["os.name", "windows"] == `
* Supported features: `manages_members`

### Provider Features {#group-provider-features}

Available features:

* `manages_aix_lam` --- The provider can manage AIX Loadable Authentication Module (LAM) system.
* `manages_local_users_and_groups` --- Allows local groups to be managed on systems that also use some other remote Name Switch Service (NSS) method of managing accounts.
* `manages_members` --- For directories where membership is an attribute of groups not users.
* `system_groups` --- The provider allows you to create system groups with lower GIDs.

Provider support:

* **aix** - _manages aix lam, manages members, manages local users and groups_
* **directoryservice** - _manages members_
* **groupadd** - No supported Provider features
* **ldap** - No supported Provider features
* **pw** - _manages members_
* **windows_adsi** - _manages members_
  




