# Developer README #

This file is intended to provide a place for developers and contributors to
document what other developers need to know about changes made to Puppet.

# Internal Structures

## Two Types of Catalog

When working on subsystems of Puppet that deal with the catalog it is important
to be aware of the two different types of Catalog.  Developers will often find
this difference while working on the static compiler and types and providers.

The two different types of catalog becomes relevant when writing spec tests
because we frequently need to wire up a fake catalog so that we can exercise
types, providers, or terminii that filter the catalog.

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
[2888](http://projects.puppetlabs.com/issues/2888).

Even more surprising, the `File[puppetdlockfile]` resource is only added to the
settings catalog if the file exists on disk.  This caused the race condition as
it will exist when a separate process holds the lock while applying the
catalog.

It may be sufficient to simply be aware of the settings catalog and the
potential for race conditions it presents.  An effective way to be reasonably
sure and track down the problem is to wrap the File.open method like so:

    # We're wrapping ourselves around the File.open method.
    # As described at: http://goo.gl/lDsv6
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

# Ruby Dependencies #

Puppet is considered an Application as it relates to the recommendation of
adding a Gemfile.lock file to the repository and the information published at
[Clarifying the Roles of the .gemspec and
Gemfile](http://yehudakatz.com/2010/12/16/clarifying-the-roles-of-the-gemspec-and-gemfile/)

To install the dependencies run: `bundle install` to install the dependencies.

A checkout of the source repository should be used in a way that provides
puppet as a gem rather than a simple Ruby library.  The parent directory should
be set along the `GEM_PATH`, preferably before other tools such as RVM that
manage gemsets using `GEM_PATH`.

For example, Puppet checked out into `/workspace/src/puppet` using `git
checkout https://github.com/puppetlabs/puppet` in `/workspace/src` can be used
with the following actions.  The trick is to symlink `gems` to `src`.

    $ cd /workspace
    $ ln -s src gems
    $ mkdir specifications
    $ pushd specifications; ln -s ../gems/puppet/puppet.gemspec; popd
    $ export GEM_PATH="/workspace:${GEM_PATH}"
    $ gem list puppet

This should list out

    puppet (2.7.19)

## Bundler ##

With a source checkout of Puppet properly setup as a gem, dependencies can be
installed using [Bundler](http://gembundler.com/)

    $ bundle install
    Fetching gem metadata from http://rubygems.org/........
    Using diff-lcs (1.1.3)
    Installing facter (1.6.11)
    Using metaclass (0.0.1)
    Using mocha (0.10.5)
    Using puppet (2.7.19) from source at /workspace/puppet-2.7.x/src/puppet
    Using rack (1.4.1)
    Using rspec-core (2.10.1)
    Using rspec-expectations (2.10.0)
    Using rspec-mocks (2.10.1)
    Using rspec (2.10.0)
    Using bundler (1.1.5)
    Your bundle is complete! Use `bundle show [gemname]` to see where a bundled gem is installed.

# UTF-8 Handling #

As Ruby 1.9 becomes more commonly used with Puppet, developers should be aware
of major changes to the way Strings and Regexp objects are handled.
Specifically, every instance of these two classes will have an encoding
attribute determined in a number of ways.

 * If the source file has an encoding specified in the magic comment at the
   top, the instance will take on that encoding.
 * Otherwise, the encoding will be determined by the LC\_LANG or LANG
   environment variables.
 * Otherwise, the encoding will default to ASCII-8BIT

## References ##

Excellent information about the differences between encodings in Ruby 1.8 and
Ruby 1.9 is published in this blog series:
[Understanding M17n](http://links.puppetlabs.com/understanding_m17n)

## Encodings of Regexp and String instances ##

In general, please be aware that Ruby 1.9 regular expressions need to be
compatible with the encoding of a string being used to match them.  If they are
not compatible you can expect to receive and error such as:

    Encoding::CompatibilityError: incompatible encoding regexp match (ASCII-8BIT
    regexp with UTF-8 string)

In addition, some escape sequences were valid in Ruby 1.8 are no longer valid
in 1.9 if the regular expression is not marked as an ASCII-8BIT object.  You
may expect errors like this in this situation:

    SyntaxError: (irb):7: invalid multibyte escape: /\xFF/

This error is particularly common when serializing a string to other
representations like JSON or YAML.  To resolve the problem you can explicitly
mark the regular expression as ASCII-8BIT using the /n flag:

    "a" =~ /\342\230\203/n

Finally, any time you're thinking of a string as an array of bytes rather than
an array of characters, common when escaping a string, you should work with
everything in ASCII-8BIT.  Changing the encoding will not change the data
itself and allow the Regexp and the String to deal with bytes rather than
characters.

Puppet provides a monkey patch to String which returns an encoding suitable for
byte manipulations:

    # Example of how to escape non ASCII printable characters for YAML.
    >> snowman = "☃"
    >> snowman.to_ascii8bit.gsub(/([\x80-\xFF])/n) { |x| "\\x#{x.unpack("C")[0].to_s(16)} }
    => "\\xe2\\x98\\x83"

If the Regexp is not marked as ASCII-8BIT using /n, then you can expect the
SyntaxError, invalid multibyte escape as mentioned above.

# Windows #

If you'd like to run Puppet from source on Windows platforms, the
include `ext/envpuppet.bat` will help.

To quickly run Puppet from source, assuming you already have Ruby installed
from [rubyinstaller.org](http://rubyinstaller.org).

    gem install sys-admin win32-process win32-dir win32-taskscheduler --no-rdoc --no-ri
    gem install win32-service --platform=mswin32 --no-rdoc --no-ri --version 0.7.1
    net use Z: "\\vmware-host\Shared Folders" /persistent:yes
    Z:
    cd <path_to_puppet>
    set PATH=%PATH%;Z:\<path_to_puppet>\ext
    envpuppet puppet --version
    2.7.9

Some spec tests are known to fail on Windows, e.g. no mount provider
on Windows, so use the following rspec exclude filter:

    cd <path_to_puppet>
    envpuppet rspec --tag ~fails_on_windows spec

This will give you a shared filesystem with your Mac and allow you to run
Puppet directly from source without using install.rb or copying files around.

## Common Issues ##

 * Don't assume file paths start with '/', as that is not a valid path on
   Windows.  Use Puppet::Util.absolute\_path? to validate that a path is fully
   qualified.

 * Use File.expand\_path('/tmp') in tests to generate a fully qualified path
   that is valid on POSIX and Windows.  In the latter case, the current working
   directory will be used to expand the path.

 * Always use binary mode when performing file I/O, unless you explicitly want
   Ruby to translate between unix and dos line endings.  For example, opening an
   executable file in text mode will almost certainly corrupt the resulting
   stream, as will occur when using:

     IO.open(path, 'r') { |f| ... }
     IO.read(path)

   If in doubt, specify binary mode explicitly:

     IO.open(path, 'rb')

 * Don't assume file paths are separated by ':'.  Use `File::PATH_SEPARATOR`
   instead, which is ':' on POSIX and ';' on Windows.

 * On Windows, `File::SEPARATOR` is '/', and `File::ALT_SEPARATOR` is '\'.  On
   POSIX systems, `File::ALT_SEPARATOR` is nil.  In general, use '/' as the
   separator as most Windows APIs, e.g. CreateFile, accept both types of
   separators.

 * Don't use waitpid/waitpid2 if you need the child process' exit code,
   as the child process may exit before it has a chance to open the
   child's HANDLE and retrieve its exit code.  Use Puppet::Util.execute.

 * Don't assume 'C' drive.  Use environment variables to look these up:

    "#{ENV['windir']}/system32/netsh.exe"

# Configuration Directory #

In Puppet 3.x we've simplified the behavior of selecting a configuration file
to load.  The intended behavior of reading `puppet.conf` is:

 1. Use the explicit configuration provided by --confdir or --config if present
 2. If running as root (`Puppet.features.root?`) then use the system
    `puppet.conf`
 3. Otherwise, use `~/.puppet/puppet.conf`.

When Puppet master is started from Rack, Puppet 3.x will read from
~/.puppet/puppet.conf by default.  This is intended behavior.  Rack
configurations should start Puppet master with an explicit configuration
directory using `ARGV << "--confdir" << "/etc/puppet"`.  Please see the
`ext/rack/files/config.ru` file for an up-to-date example.

# Determining the Puppet Version

If you need to programmatically work with the Puppet version, please use the
following:

    require 'puppet/version'
    # Get the version baked into the sourcecode:
    version = Puppet.version
    # Set the version (e.g. in a Rakefile based on `git describe`)
    Puppet.version = '2.3.4'

Please do not monkey patch the constant `Puppet::PUPPETVERSION` or obtain the
version using the constant.  The only supported way to set and get the Puppet
version is through the accessor methods.

# Static Compiler

The static compiler was added to Puppet in the 2.7.0 release.
[1](http://links.puppetlabs.com/static-compiler-announce)

The static compiler is intended to provide a configuration catalog that
requires a minimal amount of network communication in order to apply the
catalog to the system.  As implemented in Puppet 2.7.x and Puppet 3.0.x this
intention takes the form of replacing all of the source parameters of File
resources with a content parameter containing an address in the form of a
checksum.  The expected behavior is that the process applying the catalog to
the node will retrieve the file content from the FileBucket instead of the
FileServer.

The high level approach can be described as follows.  The `StaticCompiler` is a
terminus that inserts itself between the "normal" compiler terminus and the
request.  The static compiler takes the resource catalog produced by the
compiler and filters all File resources.  Any file resource that contains a
source parameter with a value starting with 'puppet://' is filtered in the
following way in a "standard" single master / networked agents deployment
scenario:

 1. The content, owner, group, and mode values are retrieved from th
     FileServer by the master.
 2. The file content is stored in the file bucket on the master.
 3. The source parameter value is stripped from the File resource.
 4. The content parameter value is set in the File resource using the form
    '{XXX}1234567890' which can be thought of as a content address indexed by
    checksum.
 5. The owner, group and mode values are set in the File resource if they are
    not already set.
 6. The filtered catalog is returned in the response.

In addition to the catalog terminus, the process requesting the catalog needs
to obtain the file content.  The default behavior of `puppet agent` is to
obtain file contents from the local client bucket.  The method we expect users
to employ to reconfigure the agent to use the server bucket is to declare the
`Filebucket[puppet]` resource with the address of the master. For example:

    node default {
      filebucket { puppet:
        server => $server,
        path   => false,
      }
      class { filetest: }
    }

This special filebucket resource named "puppet" will cause the agent to fetch
file contents specified by checksum from the remote filebucket instead of the
default clientbucket.

## Trying out the Static Compiler

Create a module that recursively downloads something.  The jeffmccune-filetest
module will recursively copy the rubygems source tree.

    $ puppet module install jeffmccune-filetest

Start the master with the StaticCompiler turned on:

    $ puppet master \
        --catalog_terminus=static_compiler \
        --verbose \
        --no-daemonize

Add the special Filebucket[puppet] resource:

    # site.pp
    node default {
      filebucket { puppet: server => $server, path => false }
      class { filetest: }
    }

Get the static catalog:

    $ puppet agent --test

You should expect all file metadata to be contained in the catalog, including a
checksum representing the content.  When managing an out of sync file resource,
the real contents should be fetched from the server instead of the
clientbucket.

Package Maintainers
=====

Software Version API
-----

Please see the public API regarding the software version as described in
`lib/puppet/version.rb`.  Puppet provides the means to easily specify the exact
version of the software packaged using the VERSION file, for example:

    $ git describe --match "3.0.*" > lib/puppet/VERSION
    $ ruby -r puppet/version -e 'puts Puppet.version'
    3.0.1-260-g9ca4e54

EOF
