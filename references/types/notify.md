---
layout: default
built_from_commit: a0909f4eae7490d52cb1e7dc81010592ba607679
title: 'Resource Type: notify'
canonical: "/puppet/latest/types/notify.html"
---

# Resource Type: notify

> **NOTE:** This page was generated from the Puppet source code on 2024-11-04 23:38:25 +0000



## notify

* [Attributes](#notify-attributes)

### Description {#notify-description}

Sends an arbitrary message, specified as a string, to the agent run-time log. It's important to note that the notify resource type is not idempotent. As a result, notifications are shown as a change on every Puppet run.

### Attributes {#notify-attributes}

<pre><code>notify { 'resource title':
  <a href="#notify-attribute-name">name</a>     =&gt; <em># <strong>(namevar)</strong> An arbitrary tag for your own reference; the...</em>
  <a href="#notify-attribute-message">message</a>  =&gt; <em># The message to be sent to the log. Note that the </em>
  <a href="#notify-attribute-withpath">withpath</a> =&gt; <em># Whether to show the full object path.  Default...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#notify-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

An arbitrary tag for your own reference; the name of the message.

([↑ Back to notify attributes](#notify-attributes))


#### message {#notify-attribute-message}

_(**Property:** This attribute represents concrete state on the target system.)_

The message to be sent to the log. Note that the value specified must be a string.

([↑ Back to notify attributes](#notify-attributes))


#### withpath {#notify-attribute-withpath}

Whether to show the full object path.

Default: `false`

Allowed values:

* `true`
* `false`

([↑ Back to notify attributes](#notify-attributes))





