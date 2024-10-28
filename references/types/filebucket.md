---
layout: default
built_from_commit: 8fcce5cb0d88b7330540e59817a7e6eae7adcdea
title: 'Resource Type: filebucket'
canonical: "/puppet/latest/types/filebucket.html"
---

# Resource Type: filebucket

> **NOTE:** This page was generated from the Puppet source code on 2024-10-28 17:41:23 +0000



## filebucket

* [Attributes](#filebucket-attributes)

### Description {#filebucket-description}

A repository for storing and retrieving file content by cryptographic checksum. Can
be local to each agent node, or centralized on a primary Puppet server. All
puppet servers provide a filebucket service that agent nodes can access
via HTTP, but you must declare a filebucket resource before any agents
will do so.

Filebuckets are used for the following features:

- **Content backups.** If the `file` type's `backup` attribute is set to
  the name of a filebucket, Puppet will back up the _old_ content whenever
  it rewrites a file; see the documentation for the `file` type for more
  details. These backups can be used for manual recovery of content, but
  are more commonly used to display changes and differences in a tool like
  Puppet Dashboard.

To use a central filebucket for backups, you will usually want to declare
a filebucket resource and a resource default for the `backup` attribute
in site.pp:

    # /etc/puppetlabs/puppet/manifests/site.pp
    filebucket { 'main':
      path   => false,                # This is required for remote filebuckets.
      server => 'puppet.example.com', # Optional; defaults to the configured primary server.
    }

    File { backup => main, }

Puppet Servers automatically provide the filebucket service, so
this will work in a default configuration. If you have a heavily
restricted Puppet Server `auth.conf` file, you may need to allow access to the
`file_bucket_file` endpoint.

### Attributes {#filebucket-attributes}

<pre><code>filebucket { 'resource title':
  <a href="#filebucket-attribute-name">name</a>   =&gt; <em># <strong>(namevar)</strong> The name of the...</em>
  <a href="#filebucket-attribute-path">path</a>   =&gt; <em># The path to the _local_ filebucket; defaults to...</em>
  <a href="#filebucket-attribute-port">port</a>   =&gt; <em># The port on which the remote server is...</em>
  <a href="#filebucket-attribute-server">server</a> =&gt; <em># The server providing the remote filebucket...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#filebucket-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the filebucket.

([↑ Back to filebucket attributes](#filebucket-attributes))


#### path {#filebucket-attribute-path}

The path to the _local_ filebucket; defaults to the value of the
`clientbucketdir` setting.  To use a remote filebucket, you _must_ set
this attribute to `false`.

([↑ Back to filebucket attributes](#filebucket-attributes))


#### port {#filebucket-attribute-port}

The port on which the remote server is listening.

This setting is _only_ consulted if the `path` attribute is set to `false`.

If this attribute is not specified, the first entry in the `server_list`
configuration setting is used, followed by the value of the `serverport`
setting if `server_list` is not set.

([↑ Back to filebucket attributes](#filebucket-attributes))


#### server {#filebucket-attribute-server}

The server providing the remote filebucket service.

This setting is _only_ consulted if the `path` attribute is set to `false`.

If this attribute is not specified, the first entry in the `server_list`
configuration setting is used, followed by the value of the `server` setting
if `server_list` is not set.

([↑ Back to filebucket attributes](#filebucket-attributes))





