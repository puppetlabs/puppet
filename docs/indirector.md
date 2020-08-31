# Indirector

> This document describes Puppet's indirector subsystem, but it has a number of limitations described below. As a result, don't introduce any new indirections or termini.

Puppet's indirector supports pluggable backends (termini) for a variety of key-value stores (indirections). Each indirection type corresponds to a particular Ruby class (the "Indirected Class" below) and values are instances of that class. Each instance's key is available from its name method. The termini can be local (e.g., on-disk files) or remote (e.g., using a REST interface to talk to a puppet master).

An indirector has five methods, which are mapped into HTTP verbs for the REST interface:

* `find(key)` - get a single value (mapped to GET or POST with a singular endpoint)
* `search(key)` - get a list of matching values (mapped to GET with a plural endpoint)
* `head(key)` - return true if the key exists (mapped to HEAD)
* `destroy(key)` - remove the key and value (mapped to DELETE)
* `save(instance)` - write the instance to the store, using the instance's name as the key (mapped to PUT)

These methods are available via the indirection class method on the indirected classes. For example, the following:

```ruby
catalog  = Puppet::Resource::Catalog.indirection.find('foo.example.com')
```

Will retrieve the catalog for the node `foo.example.com` based on the currently configured catalog terminus. If the terminus is the compiler, a new catalog will be compiled. If the terminus is `json`, it will be loaded from disk.

At startup, each indirection is configured with a terminus. In most cases, this is the default terminus defined by the indirected class, but it can be overridden by the application or face, or overridden with the route_file configuration. The available termini differ for each indirection, and are listed below.

Indirections can also have a cache, represented by a second terminus. This is a write-through cache: modifications are written both to the cache and to the primary terminus. Values fetched from the terminus are written to the cache.

## Interaction with REST
REST endpoints have the form /{prefix}/{version}/{indirection}/{key}?environment={environment}, where the indirection can be singular or plural, following normal English spelling rules. However, like most things in the English language, there are [exceptions](https://github.com/puppetlabs/puppet/blob/359ca36977e7a096385f6ea9cc0a10c03df5a7e9/lib/puppet/network/http/api/indirected_routes.rb#L269-L287). On the server side, REST responses are generated from the locally-configured endpoints.

## Indirections and Termini
Below is the list of all indirections, their associated terminus classes, and how you select between them.

In general, the appropriate terminus class is selected by the application for you (e.g., puppet agent would always use the rest terminus for most of its indirected classes), but some classes are tunable via normal settings. These will have terminus setting documentation listed with them.

### catalog
Indirected Class: `Puppet::Resource::Catalog`
Terminus Setting: `catalog_terminus`

`compiler` terminus
Compiles catalogs on demand using Puppet's compiler.

`json` terminus
Store catalogs as flat files, serialized using JSON.

`msgpack` terminus
Store catalogs as flat files, serialized using MessagePack.

`rest` terminus
Find resource catalogs over HTTP via REST.

`store_configs` terminus
Part of the "storeconfigs" feature. Should not be directly set by end users.

`yaml` terminus
Store catalogs as flat files, serialized using YAML.

### data_binding
Where to find external data bindings.

Indirected Class: `Puppet::DataBinding`
Terminus Setting: `data_binding_terminus`

`hiera` terminus
Retrieve data using Hiera.

`none` terminus
A Dummy terminus that always throws :no_such_key for data lookups.

### facts
Indirected Class: `Puppet::Node::Facts`
Terminus Setting: `facts_terminus`

`facter` terminus
Retrieve facts from Facter. This provides a somewhat abstract interface between Puppet and Facter. It's only somewhat abstract because it always returns the local host's facts, regardless of what you attempt to find.

`memory` terminus
Keep track of facts in memory but nowhere else. This is used for one-time compiles, such as what the stand-alone puppet does. To use this terminus, you must load it with the data you want it to contain.

`network_device` terminus
Retrieve facts from a network device.

`store_configs` terminus
Part of the "storeconfigs" feature. Should not be directly set by end users.

`yaml` terminus
Store client facts as flat files, serialized using YAML, or return deserialized facts from disk.

### file_bucket_file
Indirected Class: `Puppet::FileBucket::File`

`file` terminus
Store files in a directory set based on their checksums.

`rest` terminus
This is a REST based mechanism to send/retrieve file to/from the filebucket

`selector` terminus
Select the terminus based on the request

### file_content
Indirected Class: `Puppet::FileServing::Content`

`file` terminus
Retrieve file contents from disk.

`file_server` terminus
Retrieve file contents using Puppet's fileserver.

`http` terminus
Retrieve file contents from a remote HTTP server.

`rest` terminus
Retrieve file contents via a REST HTTP interface.

`selector` terminus
Select the terminus based on the request

### file_metadata
Indirected Class: `Puppet::FileServing::Metadata`

`file` terminus
Retrieve file metadata directly from the local filesystem.

`file_server` terminus
Retrieve file metadata using Puppet's fileserver.

`http` terminus
Retrieve file metadata from a remote HTTP server.

`rest` terminus
Retrieve file metadata via a REST HTTP interface.

`selector` terminus
Select the terminus based on the request

### node
Where to find node information. A node is composed of its name, its facts, and its environment.

Indirected Class: `Puppet::Node`
Terminus Setting: `node_terminus`

`exec` terminus
Call an external program to get node information. See the External Nodes page for more information.

`ldap` terminus
Search in LDAP for node configuration information. See the LDAP Nodes page for more information. This will first search for whatever the certificate name is, then (if that name contains a .) for the short name, then default.

`memory` terminus
Keep track of nodes in memory but nowhere else. This is used for one-time compiles, such as what the stand-alone puppet does. To use this terminus, you must load it with the data you want it to contain; it is only useful for developers and should generally not be chosen by a normal user.

`msgpack` terminus
Store node information as flat files, serialized using MessagePack, or deserialize stored MessagePack nodes.

`plain` terminus
Always return an empty node object. Assumes you keep track of nodes in flat file manifests. You should use it when you don't have some other, functional source you want to use, as the compiler will not work without a valid node terminus.

Note that class is responsible for merging the node's facts into the node instance before it is returned.

`rest` terminus
Get a node via REST. Puppet agent uses this to allow the puppet master to override its environment.

`store_configs` terminus
Part of the "storeconfigs" feature. Should not be directly set by end users.

`yaml` terminus
Store node information as flat files, serialized using YAML, or deserialize stored YAML nodes.

### report
Indirected Class: `Puppet::Transaction::Report`

`msgpack` terminus
Store last report as a flat file, serialized using MessagePack.

`processor` terminus
Puppet's report processor. Processes the report with each of the report types listed in the ‘reports' setting.

`rest` terminus
Get server report over HTTP via REST.

`yaml` terminus
Store last report as a flat file, serialized using YAML.

### resource
Indirected Class: `Puppet::Resource`
`ral` terminus
Manipulate resources with the resource abstraction layer. Only used internally.

`store_configs` terminus
Part of the "storeconfigs" feature. Should not be directly set by end users.

`rest` terminus
Get puppet master's status via REST. Useful because it tests the health of both the web server and the indirector.

## Limitations

Here are specific issues with the indirector:

* The indirector relies on mutable global state, such as the list of indirections and which termini and caches are currently in use.
* Termini can be configured in settings, code or `routes.yaml`, but not all termini can be configured the same way. For example, there is a `node_terminus` setting, but no `report_terminus`. There's a `catalog_cache_terminus`, but no `fact_cache_terminus`.
* There can only be one termini for an indirection at any one time. However, some applications like `puppet catalog find` need to make a REST request and then write the catalog to disk, which [means the terminus is changed at runtime](https://github.com/puppetlabs/puppet/blob/359ca36977e7a096385f6ea9cc0a10c03df5a7e9/lib/puppet/face/catalog.rb#L134-L143).
* The indirector maintains an optional terminus cache, which is often used to overcome the previous limitation. For example, `puppet agent` downloads the catalog using the `rest` terminus, but saves the cached catalog as a side effect.
* The caller is aware of the cache, and [sometimes bypasses it](https://github.com/puppetlabs/puppet/blob/359ca36977e7a096385f6ea9cc0a10c03df5a7e9/lib/puppet/configurer.rb#L297) or [forces it to be used](https://github.com/puppetlabs/puppet/blob/359ca36977e7a096385f6ea9cc0a10c03df5a7e9/lib/puppet/configurer.rb#L457).
* It's not clear when objects are cleared from the cache.
* If an exception occurs when calling the terminus, the caller can't tell whether it occurred in the terminus or the cache terminus.
* Exceptions from the remote side of the `rest` terminus, don't propagate back. So if `find` returns nil, the caller doesn't know if it the resource doesn't exist, or an exception occurred for a different reason, such as the environment doesn't exist. The `fail_on_404` option was created to handle that case, but is meaningless for non-REST termini.
* Can't process the HTTP response header to do something intelligent, e.g. to switch facts to JSON instead of PSON
* Doesn't support streaming as objects must be fully loaded in memory.
* Concrete termini, e.g. `Puppet::Node::Facts::Rest`, must inherit from an abstract terminus like `Puppet::Indirector::REST`, `Puppet::Indirector::Code`, etc. Also concrete termini can't inherit from other concrete termini.
