---
layout: default
built_from_commit: 8fcce5cb0d88b7330540e59817a7e6eae7adcdea
title: Resource types overview
canonical: "/puppet/latest/types/overview.md"
---

# Resource types overview

> **NOTE:** This page was generated from the Puppet source code on 2024-10-28 17:41:23 +0000

## List of resource types


* [exec](./exec.md)
* [file](./file.md)
* [filebucket](./filebucket.md)
* [group](./group.md)
* [notify](./notify.md)
* [package](./package.md)
* [resources](./resources.md)
* [schedule](./schedule.md)
* [service](./service.md)
* [stage](./stage.md)
* [tidy](./tidy.md)
* [user](./user.md)


## About resource types

### Built-in types and custom types

This is the documentation for Puppet's built-in resource types and providers. Additional resource types are distributed in Puppet modules.

You can find and install modules by browsing the
[Puppet Forge](http://forge.puppet.com). See each module's documentation for
information on how to use its custom resource types. For more information about creating custom types, see [Custom resources](/docs/puppet/latest/custom_resources.html).

> As of Puppet 6.0, some resource types were removed from Puppet and repackaged as individual modules. These supported type modules are still included in the `puppet-agent` package, so you don't have to download them from the Forge. See the complete list of affected types in the [supported type modules](#supported-type-modules-in-puppet-agent) section.

### Declaring resources

To manage resources on a target system, declare them in Puppet
manifests. For more details, see
[the resources page of the Puppet language reference.](/docs/puppet/latest/lang_resources.html)

You can also browse and manage resources interactively using the
`puppet resource` subcommand; run `puppet resource --help` for more information.

### Namevars and titles

All types have a special attribute called the _namevar_. This is the attribute
used to uniquely identify a resource on the target system.

Each resource has a specific namevar attribute, which is listed on this page in
each resource's reference. If you don't specify a value for the namevar, its
value defaults to the resource's _title_.

**Example of a title as a default namevar:**

```puppet
file { '/etc/passwd':
  owner => 'root',
  group => 'root',
  mode  => '0644',
}
```

In this code, `/etc/passwd` is the _title_ of the file resource.

The file type's namevar is `path`. Because we didn't provide a `path` value in
this example, the value defaults to the title, `/etc/passwd`.

**Example of a namevar:**

```puppet
file { 'passwords':
  path  => '/etc/passwd',
  owner => 'root',
  group => 'root',
  mode  => '0644',
}
```

This example is functionally similar to the previous example. Its `path`
namevar attribute has an explicitly set value separate from the title, so
its name is still `/etc/passwd`.

Other Puppet code can refer to this resource as `File['/etc/passwd']` to
declare relationships.

### Attributes, parameters, properties

The _attributes_ (sometimes called _parameters_) of a resource determine its
desired state. They either directly modify the system (internally, these are
called "properties") or they affect how the resource behaves (for instance,
adding a search path for `exec` resources or controlling directory recursion
on `file` resources).

### Providers

_Providers_ implement the same resource type on different kinds of systems.
They usually do this by calling out to external commands.

Although Puppet automatically selects an appropriate default provider, you
can override the default with the `provider` attribute. (For example, `package`
resources on Red Hat systems default to the `yum` provider, but you can specify
`provider => gem` to install Ruby libraries with the `gem` command.)

Providers often specify binaries that they require. Fully qualified binary
paths indicate that the binary must exist at that specific path, and
unqualified paths indicate that Puppet searches for the binary using the
shell path.

### Features

_Features_ are abilities that some providers might not support. Generally, a
feature corresponds to some allowed values for a resource attribute.

This is often the case with the `ensure` attribute. In most types, Puppet
doesn't create new resources when omitting `ensure` but still modifies existing
resources to match specifications in the manifest. However, in some types this
isn't always the case, or additional values provide more granular control. For
example, if a `package` provider supports the `purgeable` feature, you can
specify `ensure => purged` to delete configuration files installed by the
package.

Resource types define the set of features they can use, and providers can
declare which features they provide.

## Puppet 6.0 type changes

In Puppet 6.0, we removed some of Puppet's built-in types and moved them into individual modules.

### Supported type modules in `puppet-agent`

The following types are included in supported modules on the Forge. However, they are also included in the `puppet-agent` package, so you do not have to install them separately. See each module's README for detailed information about that type.

- [`augeas`](https://forge.puppet.com/puppetlabs/augeas_core)
- [`cron`](https://forge.puppet.com/puppetlabs/cron_core)
- [`host`](https://forge.puppet.com/puppetlabs/host_core)
- [`mount`](https://forge.puppet.com/puppetlabs/mount_core)
- [`scheduled_task`](https://forge.puppet.com/puppetlabs/scheduled_task)
- [`selboolean`](https://forge.puppet.com/puppetlabs/selinux_core)
- [`selmodule`](https://forge.puppet.com/puppetlabs/selinux_core)
- [`ssh_authorized_key`](https://forge.puppet.com/puppetlabs/sshkeys_core)
- [`sshkey`](https://forge.puppet.com/puppetlabs/sshkeys_core)
- [`yumrepo`](https://forge.puppet.com/puppetlabs/yumrepo_core)
- [`zfs`](https://forge.puppet.com/puppetlabs/zfs_core)
- [`zone`](https://forge.puppet.com/puppetlabs/zone_core)
- [`zpool`](https://forge.puppet.com/puppetlabs/zfs_core)

### Type modules available on the Forge

The following types are contained in modules that are maintained, but are not repackaged into Puppet agent. If you need to use them, you must install the modules separately. 

- [`k5login`](https://forge.puppet.com/puppetlabs/k5login_core)
- [`mailalias`](https://forge.puppet.com/puppetlabs/mailalias_core)
- [`maillist`](https://forge.puppet.com/puppetlabs/maillist_core)

### Deprecated types

The following types were deprecated with Puppet 6.0.0. They are available in modules, but are not updated. If you need to use them, you must install the modules separately.

- [`computer`](https://forge.puppet.com/puppetlabs/macdslocal_core)
- [`interface`](https://github.com/puppetlabs/puppetlabs-network_device_core) (Use the updated [`cisco_ios module`](https://forge.puppet.com/puppetlabs/cisco_ios/readme) instead.
- [`macauthorization`](https://forge.puppet.com/puppetlabs/macdslocal_core)
- [`mcx`](https://forge.puppet.com/puppetlabs/macdslocal_core)
- [The Nagios types](https://forge.puppet.com/puppetlabs/nagios_core)
- [`router`](https://github.com/puppetlabs/puppetlabs-network_device_core) (Use the updated [`cisco_ios module`](https://forge.puppet.com/puppetlabs/cisco_ios/readme) instead.
- [`vlan`](https://github.com/puppetlabs/puppetlabs-network_device_core) (Use the updated [`cisco_ios module`](https://forge.puppet.com/puppetlabs/cisco_ios/readme) instead.

## Puppet core types

For a list of core Puppet types, see the [core types cheat sheet][core-types-cheatsheet].
