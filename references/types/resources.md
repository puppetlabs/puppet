---
layout: default
built_from_commit: 942adce0b1b70f696b0f09d7109ded7559f0fa33
title: 'Resource Type: resources'
canonical: "/puppet/latest/types/resources.html"
---

# Resource Type: resources

> **NOTE:** This page was generated from the Puppet source code on 2024-08-28 16:45:59 -0700



## resources

* [Attributes](#resources-attributes)

### Description {#resources-description}

This is a metatype that can manage other resource types.  Any
metaparams specified here will be passed on to any generated resources,
so you can purge unmanaged resources but set `noop` to true so the
purging is only logged and does not actually happen.

### Attributes {#resources-attributes}

<pre><code>resources { 'resource title':
  <a href="#resources-attribute-name">name</a>               =&gt; <em># <strong>(namevar)</strong> The name of the type to be...</em>
  <a href="#resources-attribute-purge">purge</a>              =&gt; <em># Whether to purge unmanaged resources.  When set...</em>
  <a href="#resources-attribute-unless_system_user">unless_system_user</a> =&gt; <em># This keeps system users from being purged.  By...</em>
  <a href="#resources-attribute-unless_uid">unless_uid</a>         =&gt; <em># This keeps specific uids or ranges of uids from...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#resources-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the type to be managed.

([↑ Back to resources attributes](#resources-attributes))


#### purge {#resources-attribute-purge}

Whether to purge unmanaged resources.  When set to `true`, this will
delete any resource that is not specified in your configuration and is not
autorequired by any managed resources. **Note:** The `ssh_authorized_key`
resource type can't be purged this way; instead, see the `purge_ssh_keys`
attribute of the `user` type.

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

([↑ Back to resources attributes](#resources-attributes))


#### unless_system_user {#resources-attribute-unless_system_user}

This keeps system users from being purged.  By default, it
does not purge users whose UIDs are less than the minimum UID for the system (typically 500 or 1000), but you can specify
a different UID as the inclusive limit.

Allowed values:

* `true`
* `false`
* `/^\d+$/`

([↑ Back to resources attributes](#resources-attributes))


#### unless_uid {#resources-attribute-unless_uid}

This keeps specific uids or ranges of uids from being purged when purge is true.
Accepts integers, integer strings, and arrays of integers or integer strings.
To specify a range of uids, consider using the range() function from stdlib.

([↑ Back to resources attributes](#resources-attributes))





