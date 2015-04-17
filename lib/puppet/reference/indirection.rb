require 'puppet/indirector/indirection'
require 'puppet/util/checksums'
require 'puppet/file_serving/content'
require 'puppet/file_serving/metadata'

reference = Puppet::Util::Reference.newreference :indirection, :doc => "Indirection types and their terminus classes" do
  text = ""
  Puppet::Indirector::Indirection.instances.sort { |a,b| a.to_s <=> b.to_s }.each do |indirection|
    ind = Puppet::Indirector::Indirection.instance(indirection)
    name = indirection.to_s.capitalize
    text << "## " + indirection.to_s + "\n\n"

    text << Puppet::Util::Docs.scrub(ind.doc) + "\n\n"

    Puppet::Indirector::Terminus.terminus_classes(ind.name).sort { |a,b| a.to_s <=> b.to_s }.each do |terminus|
      terminus_name = terminus.to_s
      term_class = Puppet::Indirector::Terminus.terminus_class(ind.name, terminus)
      if term_class
        terminus_doc = Puppet::Util::Docs.scrub(term_class.doc)
        text << markdown_header("`#{terminus_name}` terminus", 3) << terminus_doc << "\n\n"
      else
        Puppet.warning "Could not build docs for indirector #{name.inspect}, terminus #{terminus_name.inspect}: could not locate terminus."
      end
    end
  end

  text
end

reference.header = <<HEADER

## About Indirection

Puppet's indirector support pluggable backends (termini) for a variety of key-value stores (indirections).
Each indirection type corresponds to a particular Ruby class (the "Indirected Class" below) and values are instances of that class.
Each instance's key is available from its `name` method.
The termini can be local (e.g., on-disk files) or remote (e.g., using a REST interface to talk to a puppet master).

An indirector has five methods, which are mapped into HTTP verbs for the REST interface:

* `find(key)` - get a single value (mapped to GET or POST with a singular endpoint)
* `search(key)` - get a list of matching values (mapped to GET with a plural endpoint)
* `head(key)` - return true if the key exists (mapped to HEAD)
* `destroy(key)` - remove the key van value (mapped to DELETE)
* `save(instance)` - write the instance to the store, using the instance's name as the key (mapped to PUT)

These methods are available via the `indirection` class method on the indirected classes.  For example:

    foo_cert = Puppet::SSL::Certificate.indirection.find('foo.example.com')

At startup, each indirection is configured with a terminus.
In most cases, this is the default terminus defined by the indirected class, but it can be overridden by the application or face, or overridden with the `route_file` configuration.
The available termini differ for each indirection, and are listed below.

Indirections can also have a cache, represented by a second terminus.
This is a write-through cache: modifications are written both to the cache and to the primary terminus.
Values fetched from the terminus are written to the cache.

### Interaction with REST

REST endpoints have the form `/{prefix}/{version}/{indirection}/{key}?environment={environment}`, where the indirection can be singular or plural, following normal English spelling rules.
On the server side, REST responses are generated from the locally-configured endpoints.

### Indirections and Termini

Below is the list of all indirections, their associated terminus classes, and how you select between them.

In general, the appropriate terminus class is selected by the application for you (e.g., `puppet agent` would always use the `rest`
terminus for most of its indirected classes), but some classes are tunable via normal settings.  These will have `terminus setting` documentation listed with them.

HEADER
