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
    $ pushd specifications; ln -s ../gems/puppet/puppet.gemspec; ln -s ../gems/puppet/lib; popd
    $ export GEM_PATH="/workspace:${GEM_PATH}"
    $ gem list puppet

This should list out

    puppet (2.7.19)

The final directory structure should look like this:

    /workspace/src --- git working directory
              /gems -> src
              /specifications/puppet.gemspec -> ../gems/puppet/puppet.gemspec
                             /lib -> ../gems/puppet/lib

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

# Running Tests #

Puppet Labs projects use a common convention of using Rake to run unit tests.
The tests can be run with the following rake task:

    rake spec
    # Or if using Bundler
    bundle exec rake spec

This allows the Rakefile to set up the environment beforehand if needed. This
method is how the unit tests are run in [Jenkins](https://jenkins.puppetlabs.com).

Under the hood Puppet's tests use `rspec`.  To run all of them, you can directly
use 'rspec':

    rspec
    # Or if using Bundler
    bundle exec rspec

To run a single file's worth of tests (much faster!), give the filename, and use
the nested format to see the descriptions:

    rspec spec/unit/ssl/host_spec.rb --format nested

# A brief introduction to testing in Puppet

Puppet relies heavily on automated testing to ensure that Puppet behaves as
expected and that new features don't interfere with existing behavior. There are
three primary sets of tests that Puppet uses: _unit tests_, _integration tests_,
and _acceptance tests_.

- - -

Unit tests are used to test the individual components of Puppet to ensure that
they function as expected in isolation. Unit tests are designed to hide the
actual system implementations and provide canned information so that only the
intended behavior is tested, rather than the targeted code and everything else
connected to it. Unit tests should never affect the state of the system that's
running the test.

- - -

Integration tests serve to test different units of code together to ensure that
they interact correctly. While individual methods might perform correctly, when
used with the rest of the system they might fail, so integration tests are a
higher level version of unit tests that serve to check the behavior of
individual subsystems.

All of the unit and integration tests for Puppet are kept in the spec/ directory.

- - -

Acceptance tests are used to test high level behaviors of Puppet that deal with
a number of concerns and aren't easily tested with normal unit tests. Acceptance
tests function by changing system state and checking the system after
the fact to make sure that the intended behavior occurred. Because of this
acceptance tests can be destructive, so the systems being tested should be
throwaway systems.

All of the acceptance tests for Puppet are kept in the acceptance/tests/
directory.

## Puppet Continuous integration

  * Travis-ci (unit tests only): https://travis-ci.org/puppetlabs/puppet/
  * Jenkins (unit and acceptance tests): https://jenkins.puppetlabs.com/view/Puppet%20FOSS/

## RSpec

Puppet uses RSpec to perform unit and integration tests. RSpec handles a number
of concerns to make testing easier:

  * Executing examples and ensuring the actual behavior matches the expected behavior (examples)
  * Grouping tests (describe and contexts)
  * Setting up test environments and cleaning up afterwards (before and after blocks)
  * Isolating tests (mocks and stubs)

#### Examples and expectations

At the most basic level, RSpec provides a framework for executing tests (which
are called examples) and ensuring that the actual behavior matches the expected
behavior (which are done with expectations)

```ruby
# This is an example; it sets the test name and defines the test to run
specify "one equals one" do
  # 'should' is an expectation; it adds a check to make sure that the left argument
  # matches the right argument
  1.should == 1
end

# Examples can be declared with either 'it' or 'specify'
it "one doesn't equal two" do
  1.should_not == 2
end
```

Good examples generally do as little setup as possible and only test one or two
things; it makes tests easier to understand and easier to debug.

More complete documentation on expectations is available at https://www.relishapp.com/rspec/rspec-expectations/docs

### Example groups

Example groups are fairly self explanatory; they group similar examples into a
set.

```ruby
describe "the number one" do

  it "is larger than zero" do
    1.should be > 0
  end

  it "is an odd number" do
    1.odd?.should be true
  end

  it "is not nil" do
    1.should_not be_nil
  end
end
```

Example groups have a number of uses that we'll get into later, but one of the
simplest demonstrations of what they do is how they help to format
documentation:

```
rspec ex.rb --format documentation

the number one
  is larger than zero
  is an odd number
  is not nil

Finished in 0.00516 seconds
3 examples, 0 failures
```

### Setting up and tearing down tests

Examples may require some setup before they can run, and might need to clean up
afterwards. `before` and `after` blocks can be used before this, and can be
used inside of example groups to limit how many examples they affect.

```ruby

describe "something that could warn" do
  before :each do
    # Disable warnings for this test
    $VERBOSE = nil
  end

  after do
    # Enable warnings afterwards
    $VERBOSE = true
  end

  it "doesn't generate a warning" do
    MY_CONSTANT = 1
    # reassigning a normally prints out 'warning: already initialized constant FOO'
    MY_CONSTANT = 2
  end
end
```

### Setting up helper data

Some examples may require setting up data before hand and making it available to
tests. RSpec provides helper methods with the `let` method call that can be used
inside of tests.

```ruby
describe "a helper object" do
  # This creates an array with three elements that we can retrieve in tests. A
  # new copy will be made for each test.
  let(:my_helper) do
    ['foo', 'bar', 'baz']
  end

  it "should be an array" do
    my_helper.should be_a_kind_of Array
  end

  it "should have three elements" do
    my_helper.should have(3).items
  end
end
```

Like `before` blocks, helper objects like this are used to avoid doing a lot of
setup in individual examples and share setup between similar tests.

### Isolating tests with stubs

RSpec allows you to provide fake data during testing to make sure that
individual tests are only running the code being tested. You can stub out entire
objects, or just stub out individual methods on an object. When a method is
stubbed the method itself will never be called.

While RSpec comes with its own stubbing framework, Puppet uses the Mocha
framework.

A brief usage guide for Mocha is available at http://gofreerange.com/mocha/docs/#Usage,
and an overview of Mocha expectations is available at http://gofreerange.com/mocha/docs/Mocha/Expectation.html

```ruby
describe "stubbing a method on an object" do
  let(:my_helper) do
    ['foo', 'bar', 'baz']
  end

  it 'should have three items before being stubbed' do
    my_helper.size.should == 3
  end

  describe 'when stubbing the size' do
    before do
      my_helper.stubs(:size).returns 10
    end

    it 'should have the stubbed value for size' do
      my_helper.size.should == 10
    end
  end
end
```

Entire objects can be stubbed as well.

```ruby
describe "stubbing an object" do
  let(:my_helper) do
    stub(:not_an_array, :size => 10)
  end

  it 'should have the stubbed size'
    my_helper.size.should == 10
  end
end
```

### Adding expectations with mocks

It's possible to combine the concepts of stubbing and expectations so that a
method has to be called for the test to pass (like an expectation), and can
return a fixed value (like a stub).

```ruby
describe "mocking a method on an object" do
  let(:my_helper) do
    ['foo', 'bar', 'baz']
  end

  describe "when mocking the size" do
    before do
      my_helper.expects(:size).returns 10
    end

    it "adds an expectation that a method was called" do
      my_helper.size
    end
  end
end
```

Like stubs, entire objects can be mocked.

```ruby
describe "mocking an object" do
  let(:my_helper) do
    mock(:not_an_array)
  end

  before do
    not_an_array.expects(:size).returns 10
  end

  it "adds an expectation that the method was called" do
    not_an_array.size
  end
end
```
### Writing tests without side effects

When properly written each test should be able to run in isolation, and tests
should be able to be run in any order. This makes tests more reliable and allows
a single test to be run if only that test is failing, instead of running all
17000+ tests each time something is changed. However, there are a number of ways
that can make tests fail when run in isolation or out of order.

#### Using instance variables

Puppet has a number of older tests that use `before` blocks and instance
variables to set up fixture data, instead of `let` blocks. These can retain
state between tests, which can lead to test failures when tests are run out of
order.

```ruby
# test.rb
RSpec.configure do |c|
  c.mock_framework = :mocha
end

describe "fixture data" do
  describe "using instance variables" do

    # BAD
    before :all do
      # This fixture will be created only once and will retain the `foo` stub
      # between tests.
      @fixture = stub 'test data'
    end

    it "can be stubbed" do
      @fixture.stubs(:foo).returns :bar
      @fixture.foo.should == :bar
    end

    it "should not keep state between tests" do
      # The foo stub was added in the previous test and shouldn't be present
      # in this test.
      expect { @fixture.foo }.to raise_error
    end
  end

  describe "using `let` blocks" do

    # GOOD
    # This will be recreated between tests so that state isn't retained.
    let(:fixture) { stub 'test data' }

    it "can be stubbed" do
      fixture.stubs(:foo).returns :bar
      fixture.foo.should == :bar
    end

    it "should not keep state between tests" do
      # since let blocks are regenerated between tests, the foo stub added in
      # the previous test will not be present here.
      expect { fixture.foo }.to raise_error
    end
  end
end
```

```
bundle exec rspec test.rb -fd

fixture data
  using instance variables
    can be stubbed
    should not keep state between tests (FAILED - 1)
  using `let` blocks
    can be stubbed
    should not keep state between tests

Failures:

  1) fixture data using instance variables should not keep state between tests
     Failure/Error: expect { @fixture.foo }.to raise_error
       expected Exception but nothing was raised
     # ./test.rb:17:in `block (3 levels) in <top (required)>'

Finished in 0.00248 seconds
4 examples, 1 failure

Failed examples:

rspec ./test.rb:16 # fixture data using instance variables should not keep state between tests
```


### RSpec references

  * RSpec core docs: https://www.relishapp.com/rspec/rspec-core/docs
  * RSpec guidelines with Ruby: http://betterspecs.org/

### Puppet-acceptance

[puppet-acceptance]: https://github.com/puppetlabs/puppet-acceptance
[test::unit]: http://test-unit.rubyforge.org/

Puppet has a custom acceptance testing framework called
[puppet-acceptance][puppet-acceptance] for running acceptance tests.
Puppet-acceptance runs the tests by configuring one or more VMs, copying the
test cases onto the VMs, performing the tests and collecting the results, and
ensuring that the results match the intended behavior. It uses
[test::unit][test::unit] to perform the actual assertions.

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

    C:\> cd C:\work\puppet
    C:\work\puppet> set PATH=%PATH%;C:\work\puppet\ext
    C:\work\puppet> envpuppet bundle install
    C:\work\puppet> envpuppet puppet --version
    2.7.9

When writing a test that cannot possibly run on Windows, e.g. there is
no mount type on windows, do the following:

    describe Puppet::MyClass, :unless => Puppet.features.microsoft_windows? do
      ..
    end

If the test doesn't currently pass on Windows, e.g. due to on going porting, then use an rspec conditional pending block:

    pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
      <example1>
    end

    pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
      <example2>
    end

Then run the test as:

    C:\work\puppet> envpuppet bundle exec rspec spec

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
