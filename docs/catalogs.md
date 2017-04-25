# Two Types of Catalogs

When working on subsystems of Puppet that deal with the catalog it is important
to be aware of the two different types of Catalogs.

The two different types of catalogs becomes relevant when writing spec tests
because we frequently need to wire up a fake catalog so that we can exercise
types, providers, or termini that filter the catalog.

The two different types of catalogs are so-called "resource" catalogs and "RAL"
(resource abstraction layer) catalogs.  At a high level, the resource catalog
is the in-memory object we serialize and transfer around the network.  The
compiler terminus is expected to produce a resource catalog.  The agent takes a
resource catalog and converts it into a RAL catalog.  The RAL catalog is what
is used to apply the configuration model to the system.

Resource dependency information is most easily obtained from a RAL catalog by
walking the graph instance produced by the `relationship_graph` method.

### Resource Catalog

If you're writing spec tests for something that deals with a catalog "server
side," a new catalog terminus for example, then you'll be dealing with a
resource catalog.  You can produce a resource catalog suitable for spec tests
using something like this:

    let(:catalog) do
      catalog = Puppet::Resource::Catalog.new("node-name-val") # NOT certname!
      rsrc = Puppet::Resource.new("file", "sshd_config",
        :parameters => {
          :ensure => 'file',
          :source => 'puppet:///modules/filetest/sshd_config',
        }
      )
      rsrc.file = 'site.pp'
      rsrc.line = 21
      catalog.add_resource(rsrc)
    end

The resources in this catalog may be accessed using `catalog.resources`.
Resource dependencies are not easily walked using a resource catalog however.
To walk the dependency tree convert the catalog to a RAL catalog as described
in

### RAL Catalog

The resource catalog may be converted to a RAL catalog using `catalog.to_ral`.
The RAL catalog contains `Puppet::Type` instances instead of `Puppet::Resource`
instances as is the case with the resource catalog.

One very useful feature of the RAL catalog are the methods to work with
resource relationships.  For example:

    irb> catalog = catalog.to_ral
    irb> graph = catalog.relationship_graph
    irb> pp graph.edges
    [{ Notify[alpha] => File[/tmp/file_20.txt] },
     { Notify[alpha] => File[/tmp/file_21.txt] },
     { Notify[alpha] => File[/tmp/file_22.txt] },
     { Notify[alpha] => File[/tmp/file_23.txt] },
     { Notify[alpha] => File[/tmp/file_24.txt] },
     { Notify[alpha] => File[/tmp/file_25.txt] },
     { Notify[alpha] => File[/tmp/file_26.txt] },
     { Notify[alpha] => File[/tmp/file_27.txt] },
     { Notify[alpha] => File[/tmp/file_28.txt] },
     { Notify[alpha] => File[/tmp/file_29.txt] },
     { File[/tmp/file_20.txt] => Notify[omega] },
     { File[/tmp/file_21.txt] => Notify[omega] },
     { File[/tmp/file_22.txt] => Notify[omega] },
     { File[/tmp/file_23.txt] => Notify[omega] },
     { File[/tmp/file_24.txt] => Notify[omega] },
     { File[/tmp/file_25.txt] => Notify[omega] },
     { File[/tmp/file_26.txt] => Notify[omega] },
     { File[/tmp/file_27.txt] => Notify[omega] },
     { File[/tmp/file_28.txt] => Notify[omega] },
     { File[/tmp/file_29.txt] => Notify[omega] }]

If the `relationship_graph` method is throwing exceptions at you, there's a
good chance the catalog is not a RAL catalog.

## Settings Catalog ##

Be aware that Puppet creates a mini catalog and applies this catalog locally to
manage file resource from the settings.  This behavior made it difficult and
time consuming to track down a race condition in
[PUP-1070](https://tickets.puppetlabs.com/browse/PUP-1070).

Even more surprising, the `File[puppetdlockfile]` resource is only added to the
settings catalog if the file exists on disk.  This caused the race condition as
it will exist when a separate process holds the lock while applying the
catalog.

It may be sufficient to simply be aware of the settings catalog and the
potential for race conditions it presents.  An effective way to be reasonably
sure and track down the problem is to wrap the File.open method like so:

    # We're wrapping ourselves around the File.open method.
    # As described at: https://goo.gl/lDsv6
    class File
      WHITELIST = [ /pidlock.rb:39/ ]

      class << self
        alias xxx_orig_open open
      end

      def self.open(name, *rest, &block)
        # Check the whitelist for any "good" File.open calls against the #
        puppetdlock file
        white_listed = caller(0).find do |line|
          JJM_WHITELIST.find { |re| re.match(line) }
        end

        # If you drop into IRB here, take a look at your caller, it might be
        # the ghost in the machine you're looking for.
        binding.pry if name =~ /puppetdlock/ and not white_listed
        xxx_orig_open(name, *rest, &block)
      end
    end

The settings catalog is populated by the `Puppet::Util::Settings#to\_catalog`
method.
