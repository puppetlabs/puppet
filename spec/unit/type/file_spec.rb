require 'spec_helper'

describe Puppet::Type.type(:file) do
  include PuppetSpec::Files

  # precomputed checksum values for FILE_CONTENT
  FILE_CONTENT = ''.freeze
  CHECKSUM_VALUES = {
    md5: 'd41d8cd98f00b204e9800998ecf8427e',
    md5lite: 'd41d8cd98f00b204e9800998ecf8427e',
    sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    sha256lite: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    sha1: 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
    sha1lite: 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
    sha224: 'd14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f',
    sha384: '38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b',
    sha512: 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e',
    mtime: 'Jan 26 13:59:49 2016',
    ctime: 'Jan 26 13:59:49 2016'
  }.freeze

  INVALID_CHECKSUM_VALUES = {
    md5: '00000000000000000000000000000000',
    md5lite: '00000000000000000000000000000000',
    sha256: '0000000000000000000000000000000000000000000000000000000000000000',
    sha256lite: '0000000000000000000000000000000000000000000000000000000000000000',
    sha1: '0000000000000000000000000000000000000000',
    sha1lite: '0000000000000000000000000000000000000000',
    sha224: '00000000000000000000000000000000000000000000000000000000',
    sha384: '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    sha512: '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
  }.freeze

  let(:path) { tmpfile('file_testing') }
  let(:file) { described_class.new(:path => path, :catalog => catalog) }
  let(:provider) { file.provider }
  let(:catalog) { Puppet::Resource::Catalog.new }

  before do
    allow(Puppet.features).to receive("posix?").and_return(true)
  end

  describe "the path parameter" do
    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should remove trailing slashes" do
        file[:path] = "/foo/bar/baz/"
        expect(file[:path]).to eq("/foo/bar/baz")
      end

      it "should remove double slashes" do
        file[:path] = "/foo/bar//baz"
        expect(file[:path]).to eq("/foo/bar/baz")
      end

      it "should remove triple slashes" do
        file[:path] = "/foo/bar///baz"
        expect(file[:path]).to eq("/foo/bar/baz")
      end

      it "should remove trailing double slashes" do
        file[:path] = "/foo/bar/baz//"
        expect(file[:path]).to eq("/foo/bar/baz")
      end

      it "should leave a single slash alone" do
        file[:path] = "/"
        expect(file[:path]).to eq("/")
      end

      it "should accept and collapse a double-slash at the start of the path" do
        file[:path] = "//tmp/xxx"
        expect(file[:path]).to eq('/tmp/xxx')
      end

      it "should accept and collapse a triple-slash at the start of the path" do
        file[:path] = "///tmp/xxx"
        expect(file[:path]).to eq('/tmp/xxx')
      end
    end

    describe "on Windows systems", :if => Puppet::Util::Platform.windows? do
      it "should remove trailing slashes" do
        file[:path] = "X:/foo/bar/baz/"
        expect(file[:path]).to eq("X:/foo/bar/baz")
      end

      it "should remove double slashes" do
        file[:path] = "X:/foo/bar//baz"
        expect(file[:path]).to eq("X:/foo/bar/baz")
      end

      it "should remove trailing double slashes" do
        file[:path] = "X:/foo/bar/baz//"
        expect(file[:path]).to eq("X:/foo/bar/baz")
      end

      it "should leave a drive letter with a slash alone" do
        file[:path] = "X:/"
        expect(file[:path]).to eq("X:/")
      end

      it "should not accept a drive letter without a slash" do
        expect { file[:path] = "X:" }.to raise_error(/File paths must be fully qualified/)
      end

      describe "when using UNC filenames", :if => Puppet::Util::Platform.windows? do
        it "should remove trailing slashes" do
          file[:path] = "//localhost/foo/bar/baz/"
          expect(file[:path]).to eq("//localhost/foo/bar/baz")
        end

        it "should remove double slashes" do
          file[:path] = "//localhost/foo/bar//baz"
          expect(file[:path]).to eq("//localhost/foo/bar/baz")
        end

        it "should remove trailing double slashes" do
          file[:path] = "//localhost/foo/bar/baz//"
          expect(file[:path]).to eq("//localhost/foo/bar/baz")
        end

        it "should remove a trailing slash from a sharename" do
          file[:path] = "//localhost/foo/"
          expect(file[:path]).to eq("//localhost/foo")
        end

        it "should not modify a sharename" do
          file[:path] = "//localhost/foo"
          expect(file[:path]).to eq("//localhost/foo")
        end
      end
    end
  end

  describe "the backup parameter" do
    [false, 'false', :false].each do |value|
      it "should disable backup if the value is #{value.inspect}" do
        file[:backup] = value
        expect(file[:backup]).to eq(false)
      end
    end

    [true, 'true', '.puppet-bak'].each do |value|
      it "should use .puppet-bak if the value is #{value.inspect}" do
        file[:backup] = value
        expect(file[:backup]).to eq('.puppet-bak')
      end
    end

    it "should use the provided value if it's any other string" do
      file[:backup] = "over there"
      expect(file[:backup]).to eq("over there")
    end

    it "should fail if backup is set to anything else" do
      expect do
        file[:backup] = 97
      end.to raise_error(Puppet::Error, /Invalid backup type 97/)
    end
  end

  describe "the recurse parameter" do
    it "should default to recursion being disabled" do
      expect(file[:recurse]).to be_falsey
    end

    [true, "true", "remote"].each do |value|
      it "should consider #{value} to enable recursion" do
        file[:recurse] = value
        expect(file[:recurse]).to be_truthy
      end
    end

    it "should not allow numbers" do
      expect { file[:recurse] = 10 }.to raise_error(
        Puppet::Error, /Parameter recurse failed on File\[[^\]]+\]: Invalid recurse value 10/)
    end

    [false, "false"].each do |value|
      it "should consider #{value} to disable recursion" do
        file[:recurse] = value
        expect(file[:recurse]).to be_falsey
      end
    end
  end

  describe "the recurselimit parameter" do
    it "should accept integers" do
      file[:recurselimit] = 12
      expect(file[:recurselimit]).to eq(12)
    end

    it "should munge string numbers to number numbers" do
      file[:recurselimit] = '12'
      expect(file[:recurselimit]).to eq(12)
    end

    it "should fail if given a non-number" do
      expect do
        file[:recurselimit] = 'twelve'
      end.to raise_error(Puppet::Error, /Invalid value "twelve"/)
    end
  end

  describe "the replace parameter" do
    [true, :true, :yes].each do |value|
      it "should consider #{value} to be true" do
        file[:replace] = value
        expect(file[:replace]).to be_truthy
      end
    end

    [false, :false, :no].each do |value|
      it "should consider #{value} to be false" do
        file[:replace] = value
        expect(file[:replace]).to be_falsey
      end
    end
  end

  describe ".instances" do
    it "should return an empty array" do
      expect(described_class.instances).to eq([])
    end
  end

  describe "#bucket" do
    it "should return nil if backup is off" do
      file[:backup] = false
      expect(file.bucket).to eq(nil)
    end

    it "should not return a bucket if using a file extension for backup" do
      file[:backup] = '.backup'

      expect(file.bucket).to eq(nil)
    end

    it "should return the default filebucket if using the 'puppet' filebucket" do
      file[:backup] = 'puppet'
      bucket = double('bucket')
      allow(file).to receive(:default_bucket).and_return(bucket)

      expect(file.bucket).to eq(bucket)
    end

    it "should fail if using a remote filebucket and no catalog exists" do
      file.catalog = nil
      file[:backup] = 'my_bucket'

      expect { file.bucket }.to raise_error(Puppet::Error, "Can not find filebucket for backups without a catalog")
    end

    it "should fail if the specified filebucket isn't in the catalog" do
      file[:backup] = 'my_bucket'

      expect { file.bucket }.to raise_error(Puppet::Error, "Could not find filebucket my_bucket specified in backup")
    end

    it "should use the specified filebucket if it is in the catalog" do
      file[:backup] = 'my_bucket'
      filebucket = Puppet::Type.type(:filebucket).new(:name => 'my_bucket')
      catalog.add_resource(filebucket)

      expect(file.bucket).to eq(filebucket.bucket)
    end
  end

  describe "#asuser" do
    before :each do
      # Mocha won't let me just stub SUIDManager.asuser to yield and return,
      # but it will do exactly that if we're not root.
      allow(Puppet::Util::SUIDManager).to receive(:root?).and_return(false)
    end

    it "should return the desired owner if they can write to the parent directory" do
      file[:owner] = 1001
      allow(FileTest).to receive(:writable?).with(File.dirname file[:path]).and_return(true)

      expect(file.asuser).to eq(1001)
    end

    it "should return nil if the desired owner can't write to the parent directory" do
      file[:owner] = 1001
      allow(FileTest).to receive(:writable?).with(File.dirname file[:path]).and_return(false)

      expect(file.asuser).to eq(nil)
    end

    it "should return nil if not managing owner" do
      expect(file.asuser).to eq(nil)
    end
  end

  describe "#exist?" do
    it "should be considered existent if it can be stat'ed" do
      expect(file).to receive(:stat).and_return(double('stat'))
      expect(file).to be_exist
    end

    it "should be considered nonexistent if it can not be stat'ed" do
      expect(file).to receive(:stat).and_return(nil)
      expect(file).to_not be_exist
    end
  end

  describe "#eval_generate" do
    before do
      @graph = double('graph', :add_edge => nil)
      allow(catalog).to receive(:relationship_graph).and_return(@graph)
    end

    it "should recurse if recursion is enabled" do
      resource = double('resource', :[] => 'resource')
      expect(file).to receive(:recurse).and_return([resource])

      file[:recurse] = true

      expect(file.eval_generate).to eq([resource])
    end

    it "should not recurse if recursion is disabled" do
      expect(file).not_to receive(:recurse)

      file[:recurse] = false

      expect(file.eval_generate).to eq([])
    end
  end

  describe "#ancestors" do
    it "should return the ancestors of the file, in ascending order" do
      file = described_class.new(:path => make_absolute("/tmp/foo/bar/baz/qux"))

      pieces = %W[#{make_absolute('/')} tmp foo bar baz]

      ancestors = file.ancestors

      expect(ancestors).not_to be_empty
      ancestors.reverse.each_with_index do |path,i|
        expect(path).to eq(File.join(*pieces[0..i]))
      end
    end
  end

  describe "#flush" do
    it "should flush all properties that respond to :flush" do
      file[:source] = File.expand_path(__FILE__)
      expect(file.parameter(:source)).to receive(:flush)
      file.flush
    end

    it "should reset its stat reference" do
      FileUtils.touch(path)
      stat1 = file.stat

      expect(file.stat).to equal(stat1)

      file.flush

      expect(file.stat).not_to equal(stat1)
    end
  end

  describe "#initialize" do
    it "should remove a trailing slash from the title to create the path" do
      title = File.expand_path("/abc/\n\tdef/")
      file = described_class.new(:title => title)
      expect(file[:path]).to eq(title)
    end

    it "should allow a single slash for a title and create the path" do
      title = File.expand_path("/")
      file = described_class.new(:title => title)
      expect(file[:path]).to eq(title)
    end

    it "should allow multiple slashes for a title and create the path" do
      title = File.expand_path("/") + "//"
      file = described_class.new(:title => title)
      expect(file[:path]).to eq(File.expand_path("/"))
    end

    it "should set a desired 'ensure' value if none is set and 'content' is set" do
      file = described_class.new(:path => path, :content => "/foo/bar")
      expect(file[:ensure]).to eq(:file)
    end

    it "should set a desired 'ensure' value if none is set and 'target' is set", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
      file = described_class.new(:path => path, :target => File.expand_path(__FILE__))
      expect(file[:ensure]).to eq(:link)
    end

    describe "marking parameters as sensitive" do
      it "marks sensitive, content, and ensure as sensitive when source is sensitive" do
        resource = Puppet::Resource.new(:file, make_absolute("/tmp/foo"), :parameters => {:source => make_absolute('/tmp/bar')}, :sensitive_parameters => [:source])
        file = described_class.new(resource)
        expect(file.parameter(:source).sensitive).to eq true
        expect(file.property(:content).sensitive).to eq true
        expect(file.property(:ensure).sensitive).to eq true
      end

      it "marks ensure as sensitive when content is sensitive" do
        resource = Puppet::Resource.new(:file, make_absolute("/tmp/foo"), :parameters => {:content => 'hello world!'}, :sensitive_parameters => [:content])
        file = described_class.new(resource)
        expect(file.property(:ensure).sensitive).to eq true
      end
    end
  end

  describe "#mark_children_for_purging" do
    it "should set each child's ensure to absent" do
      paths = %w[foo bar baz]
      children = {}
      paths.each do |child|
        children[child] = described_class.new(:path => File.join(path, child), :ensure => :present)
      end

      file.mark_children_for_purging(children)

      expect(children.length).to eq(3)
      children.values.each do |child|
        expect(child[:ensure]).to eq(:absent)
      end
    end

    it "should skip children which have a source" do
      child = described_class.new(:path => path, :ensure => :present, :source => File.expand_path(__FILE__))

      file.mark_children_for_purging('foo' => child)

      expect(child[:ensure]).to eq(:present)
    end
  end

  describe "#newchild" do
    it "should create a new resource relative to the parent" do
      child = file.newchild('bar')

      expect(child).to be_a(described_class)
      expect(child[:path]).to eq(File.join(file[:path], 'bar'))
    end

    {
      :ensure => :present,
      :recurse => true,
      :recurselimit => 5,
      :target => "some_target",
      :source => File.expand_path("some_source"),
    }.each do |param, value|
      it "should omit the #{param} parameter", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
        # Make a new file, because we have to set the param at initialization
        # or it wouldn't be copied regardless.
        file = described_class.new(:path => path, param => value)
        child = file.newchild('bar')
        expect(child[param]).not_to eq(value)
      end
    end

    it "should copy all of the parent resource's 'should' values that were set at initialization" do
      parent = described_class.new(:path => path, :owner => 'root', :group => 'wheel')

      child = parent.newchild("my/path")

      expect(child[:owner]).to eq('root')
      expect(child[:group]).to eq('wheel')
    end

    it "should not copy default values to the new child" do
      child = file.newchild("my/path")
      expect(child.original_parameters).not_to include(:backup)
    end

    it "should not copy values to the child which were set by the source" do
      source = File.expand_path(__FILE__)
      file[:source] = source
      metadata = double('metadata', :owner => "root", :group => "root", :mode => '0755', :ftype => "file", :checksum => "{md5}whatever", :checksum_type => "md5", :source => source)
      allow(file.parameter(:source)).to receive(:metadata).and_return(metadata)

      file.parameter(:source).copy_source_values

      expect(file.class).to receive(:new) do |arg|
        expect(arg[:group]).to be_nil
      end
      file.newchild("my/path")
    end
  end

  describe "#purge?" do
    it "should return false if purge is not set" do
      expect(file).to_not be_purge
    end

    it "should return true if purge is set to true" do
      file[:purge] = true

      expect(file).to be_purge
    end

    it "should return false if purge is set to false" do
      file[:purge] = false

      expect(file).to_not be_purge
    end
  end

  describe "#recurse" do
    let(:name) { 'bar' }
    let(:child) { double('puppet_type_file') }

    before do
      file[:recurse] = true
      @metadata = Puppet::FileServing::Metadata
    end

    describe "and a source is set" do
      it "should pass the already-discovered resources to recurse_remote" do
        file[:source] = File.expand_path(__FILE__)
        allow(child).to receive(:[]).with(:path).and_return(name)
        allow(file).to receive(:recurse_local).and_return(name => child)
        expect(file).to receive(:recurse_remote).with(name => child).and_return([])
        file.recurse
      end
    end

    describe "and a target is set" do
      it "should use recurse_link" do
        file[:target] = File.expand_path(__FILE__)
        allow(child).to receive(:[]).with(:path).and_return(name)
        allow(file).to receive(:recurse_local).and_return(name => child)
        expect(file).to receive(:recurse_link).with(name => child).and_return([])
        file.recurse
      end
    end

    it "should use recurse_local if recurse is not remote" do
      expect(file).to receive(:recurse_local).and_return({})
      file.recurse
    end

    it "should not use recurse_local if recurse is remote" do
      file[:recurse] = :remote
      expect(file).not_to receive(:recurse_local)
      file.recurse
    end

    it "should return the generated resources as an array sorted by file path" do
      one = double('one', :[] => "/one")
      two = double('two', :[] => "/one/two")
      three = double('three', :[] => "/three")
      expect(file).to receive(:recurse_local).and_return(:one => one, :two => two, :three => three)
      expect(file.recurse).to eq([one, two, three])
    end

    describe "and purging is enabled" do
      before do
        file[:purge] = true
      end

      it "should mark each file for removal" do
        local = described_class.new(:path => path, :ensure => :present)
        expect(file).to receive(:recurse_local).and_return("local" => local)

        file.recurse
        expect(local[:ensure]).to eq(:absent)
      end

      it "should not remove files that exist in the remote repository" do
        pending("FIXME: This test has been broken since it was introduced in c189b46e3f1 because of = vs ==")
        file[:source] = File.expand_path(__FILE__)
        expect(file).to receive(:recurse_local).and_return({})

        remote = described_class.new(:path => path, :source => File.expand_path(__FILE__), :ensure => :present)

        expect(file).to receive(:recurse_remote).with(hash_including("remote" => remote))

        file.recurse

        expect(remote[:ensure]).not_to eq(:absent)
      end
    end

  end

  describe "#remove_less_specific_files" do
    it "should remove any nested files that are already in the catalog" do
      foo = described_class.new :path => File.join(file[:path], 'foo')
      bar = described_class.new :path => File.join(file[:path], 'bar')
      baz = described_class.new :path => File.join(file[:path], 'baz')

      catalog.add_resource(foo)
      catalog.add_resource(bar)

      expect(file.remove_less_specific_files([foo, bar, baz])).to eq([baz])
    end

  end

  describe "#recurse?" do
    it "should be true if recurse is true" do
      file[:recurse] = true
      expect(file).to be_recurse
    end

    it "should be true if recurse is remote" do
      file[:recurse] = :remote
      expect(file).to be_recurse
    end

    it "should be false if recurse is false" do
      file[:recurse] = false
      expect(file).to_not be_recurse
    end
  end

  describe "#recurse_link" do
    before do
      @first = double('first', :relative_path => "first", :full_path => "/my/first", :ftype => "directory")
      @second = double('second', :relative_path => "second", :full_path => "/my/second", :ftype => "file")

      @resource = double('file', :[]= => nil)
    end

    it "should pass its target to the :perform_recursion method" do
      file[:target] = "mylinks"
      expect(file).to receive(:perform_recursion).with("mylinks").and_return([@first])
      allow(file).to receive(:newchild).and_return(@resource)
      file.recurse_link({})
    end

    it "should ignore the recursively-found '.' file and configure the top-level file to create a directory" do
      allow(@first).to receive(:relative_path).and_return(".")
      file[:target] = "mylinks"
      expect(file).to receive(:perform_recursion).with("mylinks").and_return([@first])
      expect(file).not_to receive(:newchild)
      expect(file).to receive(:[]=).with(:ensure, :directory)
      file.recurse_link({})
    end

    it "should create a new child resource for each generated metadata instance's relative path that doesn't already exist in the children hash" do
      expect(file).to receive(:perform_recursion).and_return([@first, @second])
      expect(file).to receive(:newchild).with(@first.relative_path).and_return(@resource)
      file.recurse_link("second" => @resource)
    end

    it "should not create a new child resource for paths that already exist in the children hash" do
      expect(file).to receive(:perform_recursion).and_return([@first])
      expect(file).not_to receive(:newchild)
      file.recurse_link("first" => @resource)
    end

    it "should set the target to the full path of discovered file and set :ensure to :link if the file is not a directory", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
      allow(file).to receive(:perform_recursion).and_return([@first, @second])
      file.recurse_link("first" => @resource, "second" => file)

      expect(file[:ensure]).to eq(:link)
      expect(file[:target]).to eq("/my/second")
    end

    it "should :ensure to :directory if the file is a directory" do
      allow(file).to receive(:perform_recursion).and_return([@first, @second])
      file.recurse_link("first" => file, "second" => @resource)

      expect(file[:ensure]).to eq(:directory)
    end

    it "should return a hash with both created and existing resources with the relative paths as the hash keys" do
      expect(file).to receive(:perform_recursion).and_return([@first, @second])
      allow(file).to receive(:newchild).and_return(file)
      expect(file.recurse_link("second" => @resource)).to eq({"second" => @resource, "first" => file})
    end
  end

  describe "#recurse_local" do
    before do
      @metadata = double('metadata', :relative_path => "my/file")
    end

    it "should pass its path to the :perform_recursion method" do
      expect(file).to receive(:perform_recursion).with(file[:path]).and_return([@metadata])
      allow(file).to receive(:newchild)
      file.recurse_local
    end

    it "should return an empty hash if the recursion returns nothing" do
      expect(file).to receive(:perform_recursion).and_return(nil)
      expect(file.recurse_local).to eq({})
    end

    it "should create a new child resource with each generated metadata instance's relative path" do
      expect(file).to receive(:perform_recursion).and_return([@metadata])
      expect(file).to receive(:newchild).with(@metadata.relative_path).and_return("fiebar")
      file.recurse_local
    end

    it "should not create a new child resource for the '.' directory" do
      allow(@metadata).to receive(:relative_path).and_return(".")

      expect(file).to receive(:perform_recursion).and_return([@metadata])
      expect(file).not_to receive(:newchild)
      file.recurse_local
    end

    it "should return a hash of the created resources with the relative paths as the hash keys" do
      expect(file).to receive(:perform_recursion).and_return([@metadata])
      expect(file).to receive(:newchild).with("my/file").and_return("fiebar")
      expect(file.recurse_local).to eq({"my/file" => "fiebar"})
    end

    it "should set checksum_type to none if this file checksum is none" do
      file[:checksum] = :none
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(checksum_type: :none)).and_return([@metadata])
      expect(file).to receive(:newchild).with("my/file").and_return("fiebar")
      file.recurse_local
    end
  end

  describe "#recurse_remote" do
    let(:my) { File.expand_path('/my') }

    before do
      file[:source] = "puppet://foo/bar"

      @first = Puppet::FileServing::Metadata.new(my, :relative_path => "first")
      @second = Puppet::FileServing::Metadata.new(my, :relative_path => "second")
      allow(@first).to receive(:ftype).and_return("directory")
      allow(@second).to receive(:ftype).and_return("directory")

      @parameter = double('property', :metadata= => nil)
      @resource = double('file', :[]= => nil, :parameter => @parameter)
    end

    it "should pass its source to the :perform_recursion method" do
      data = Puppet::FileServing::Metadata.new(File.expand_path("/whatever"), :relative_path => "foobar")
      expect(file).to receive(:perform_recursion).with("puppet://foo/bar").and_return([data])
      allow(file).to receive(:newchild).and_return(@resource)
      file.recurse_remote({})
    end

    it "should not recurse when the remote file is not a directory" do
      data = Puppet::FileServing::Metadata.new(File.expand_path("/whatever"), :relative_path => ".")
      allow(data).to receive(:ftype).and_return("file")
      expect(file).to receive(:perform_recursion).with("puppet://foo/bar").and_return([data])
      expect(file).not_to receive(:newchild)
      file.recurse_remote({})
    end

    it "should set the source of each returned file to the searched-for URI plus the found relative path" do
      expect(@first).to receive(:source=).with(File.join("puppet://foo/bar", @first.relative_path))
      expect(file).to receive(:perform_recursion).and_return([@first])
      allow(file).to receive(:newchild).and_return(@resource)
      file.recurse_remote({})
    end

    it "should create a new resource for any relative file paths that do not already have a resource" do
      allow(file).to receive(:perform_recursion).and_return([@first])
      expect(file).to receive(:newchild).with("first").and_return(@resource)
      expect(file.recurse_remote({})).to eq({"first" => @resource})
    end

    it "should not create a new resource for any relative file paths that do already have a resource" do
      allow(file).to receive(:perform_recursion).and_return([@first])
      expect(file).not_to receive(:newchild)
      file.recurse_remote("first" => @resource)
    end

    it "should set the source of each resource to the source of the metadata" do
      allow(file).to receive(:perform_recursion).and_return([@first])
      allow(@resource).to receive(:[]=)
      expect(@resource).to receive(:[]=).with(:source, File.join("puppet://foo/bar", @first.relative_path))
      file.recurse_remote("first" => @resource)
    end

    it "should set the checksum parameter based on the metadata" do
      allow(file).to receive(:perform_recursion).and_return([@first])
      allow(@resource).to receive(:[]=)
      expect(@resource).to receive(:[]=).with(:checksum, "md5")
      file.recurse_remote("first" => @resource)
    end

    it "should store the metadata in the source property for each resource so the source does not have to requery the metadata" do
      allow(file).to receive(:perform_recursion).and_return([@first])
      expect(@resource).to receive(:parameter).with(:source).and_return(@parameter)

      expect(@parameter).to receive(:metadata=).with(@first)

      file.recurse_remote("first" => @resource)
    end

    it "should not create a new resource for the '.' file" do
      allow(@first).to receive(:relative_path).and_return(".")
      allow(file).to receive(:perform_recursion).and_return([@first])

      expect(file).not_to receive(:newchild)

      file.recurse_remote({})
    end

    it "should store the metadata in the main file's source property if the relative path is '.'" do
      allow(@first).to receive(:relative_path).and_return(".")
      allow(file).to receive(:perform_recursion).and_return([@first])

      expect(file.parameter(:source)).to receive(:metadata=).with(@first)

      file.recurse_remote("first" => @resource)
    end

    it "should update the main file's checksum parameter if the relative path is '.'" do
      allow(@first).to receive(:relative_path).and_return(".")
      allow(file).to receive(:perform_recursion).and_return([@first])

      allow(file).to receive(:[]=)
      expect(file). to receive(:[]=).with(:checksum, "md5")

      file.recurse_remote("first" => @resource)
    end

    describe "and multiple sources are provided" do
      let(:sources) do
        h = {}
        %w{/a /b /c /d}.each do |key|
          h[key] = Puppet::Util.uri_unescape(Puppet::Util.path_to_uri(File.expand_path(key)).to_s)
        end
        h
      end

      describe "and :sourceselect is set to :first" do
        it "should create file instances for the results for the first source to return any values" do
          data = Puppet::FileServing::Metadata.new(File.expand_path("/whatever"), :relative_path => "foobar")
          file[:source] = sources.keys.sort.map { |key| File.expand_path(key) }
          expect(file).to receive(:perform_recursion).with(sources['/a']).and_return(nil)
          expect(file).to receive(:perform_recursion).with(sources['/b']).and_return([])
          expect(file).to receive(:perform_recursion).with(sources['/c']).and_return([data])
          expect(file).not_to receive(:perform_recursion).with(sources['/d'])
          expect(file).to receive(:newchild).with("foobar").and_return(@resource)
          file.recurse_remote({})
        end
      end

      describe "and :sourceselect is set to :all" do
        before do
          file[:sourceselect] = :all
        end

        it "should return every found file that is not in a previous source" do
          klass = Puppet::FileServing::Metadata

          file[:source] = abs_path = %w{/a /b /c /d}.map {|f| File.expand_path(f) }
          allow(file).to receive(:newchild).and_return(@resource)

          one = [klass.new(abs_path[0], :relative_path => "a")]
          expect(file).to receive(:perform_recursion).with(sources['/a']).and_return(one)
          expect(file).to receive(:newchild).with("a").and_return(@resource)

          two = [klass.new(abs_path[1], :relative_path => "a"), klass.new(abs_path[1], :relative_path => "b")]
          expect(file).to receive(:perform_recursion).with(sources['/b']).and_return(two)
          expect(file).to receive(:newchild).with("b").and_return(@resource)

          three = [klass.new(abs_path[2], :relative_path => "a"), klass.new(abs_path[2], :relative_path => "c")]
          expect(file).to receive(:perform_recursion).with(sources['/c']).and_return(three)
          expect(file).to receive(:newchild).with("c").and_return(@resource)
          expect(file).to receive(:perform_recursion).with(sources['/d']).and_return([])

          file.recurse_remote({})
        end
      end
    end
  end

  describe "#perform_recursion", :uses_checksums => true do
    it "should use Metadata to do its recursion" do
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search)
      file.perform_recursion(file[:path])
    end

    it "should use the provided path as the key to the search" do
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with("/foo", anything)
      file.perform_recursion("/foo")
    end

    it "should return the results of the metadata search" do
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).and_return("foobar")
      expect(file.perform_recursion(file[:path])).to eq("foobar")
    end

    it "should pass its recursion value to the search" do
      file[:recurse] = true
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(recurse: true))
      file.perform_recursion(file[:path])
    end

    it "should pass true if recursion is remote" do
      file[:recurse] = :remote
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(recurse: true))
      file.perform_recursion(file[:path])
    end

    it "should pass its recursion limit value to the search" do
      file[:recurselimit] = 10
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(recurselimit: 10))
      file.perform_recursion(file[:path])
    end

    it "should configure the search to ignore or manage links" do
      file[:links] = :manage
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(links: :manage))
      file.perform_recursion(file[:path])
    end

    it "should pass its 'ignore' setting to the search if it has one" do
      file[:ignore] = %w{.svn CVS}
      expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(ignore: %w{.svn CVS}))
      file.perform_recursion(file[:path])
    end

    with_digest_algorithms do
      it "it should pass its 'checksum' setting #{metadata[:digest_algorithm]} to the search" do
        file[:source] = File.expand_path('/foo')
        expect(Puppet::FileServing::Metadata.indirection).to receive(:search).with(anything, hash_including(checksum_type: digest_algorithm.intern))
        file.perform_recursion(file[:path])
      end
    end
  end

  describe "#remove_existing" do
    it "should do nothing if the file doesn't exist" do
      expect(file.remove_existing(:file)).to eq(false)
    end

    it "should fail if it can't backup the file" do
      # Default: file[:backup] = true
      allow(file).to receive(:stat).and_return(double('stat', :ftype => 'file'))
      allow(file).to receive(:perform_backup).and_return(false)

      expect { file.remove_existing(:file) }.to raise_error(Puppet::Error, /Could not back up; will not remove/)
    end

    describe "backing up directories" do
      it "should not backup directories if backup is true and force is false" do
        # Default: file[:backup] = true
        file[:force] = false
        allow(file).to receive(:stat).and_return(double('stat', :ftype => 'directory'))

        expect(file).not_to receive(:perform_backup)
        expect(file).to receive(:warning).with("Could not back up file of type directory")
        expect(file.remove_existing(:file)).to eq(false)
      end

      it "should backup directories if backup is true and force is true" do
        # Default: file[:backup] = true
        file[:force] = true
        allow(file).to receive(:stat).and_return(double('stat', :ftype => 'directory'))

        expect(FileUtils).to receive(:rmtree).with(file[:path])
        expect(file).to receive(:perform_backup).and_return(true)

        expect(file.remove_existing(:file)).to eq(true)
      end
    end

    it "should not do anything if the file is already the right type and not a link" do
      allow(file).to receive(:stat).and_return(double('stat', :ftype => 'file'))

      expect(file.remove_existing(:file)).to eq(false)
    end

    it "should not remove directories and should not invalidate the stat unless force is true" do
      file[:force] = false
      # Actually call stat to set @needs_stat to nil
      file.stat
      allow(file).to receive(:stat).and_return(double('stat', :ftype => 'directory'))

      expect(file.instance_variable_get(:@stat)).to eq(nil)
    end

    it "should remove a directory if backup is true and force is true" do
      # Default: file[:backup] = true
      file[:force] = true
      allow(file).to receive(:stat).and_return(double('stat', :ftype => 'directory'))

      expect(FileUtils).to receive(:rmtree).with(file[:path])

      expect(file.remove_existing(:file)).to eq(true)
    end

    it "should remove an existing file" do
      allow(file).to receive(:perform_backup).and_return(true)
      FileUtils.touch(path)

      expect(file.remove_existing(:directory)).to eq(true)

      expect(Puppet::FileSystem.exist?(file[:path])).to eq(false)
    end

    it "should remove an existing link", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
      allow(file).to receive(:perform_backup).and_return(true)

      target = tmpfile('link_target')
      FileUtils.touch(target)
      Puppet::FileSystem.symlink(target, path)
      file[:target] = target

      expect(file.remove_existing(:directory)).to eq(true)

      expect(Puppet::FileSystem.exist?(file[:path])).to eq(false)
    end

    it "should fail if the file is not a directory, link, file, fifo, socket, or is unknown" do
      allow(file).to receive(:stat).and_return(double('stat', :ftype => 'blockSpecial'))

      expect(file).to receive(:warning).with("Could not back up file of type blockSpecial")
      expect { file.remove_existing(:file) }.to raise_error(Puppet::Error, /Could not remove files of type blockSpecial/)
    end

    it "should invalidate the existing stat of the file" do
      # Actually call stat to set @needs_stat to nil
      file.stat
      allow(file).to receive(:stat).and_return(double('stat', :ftype => 'file'))

      allow(Puppet::FileSystem).to receive(:unlink)

      expect(file.remove_existing(:directory)).to eq(true)
      expect(file.instance_variable_get(:@stat)).to eq(:needs_stat)
    end
  end

  describe "#retrieve" do
    it "should copy the source values if the 'source' parameter is set" do
      file[:source] = File.expand_path('/foo/bar')
      expect(file.parameter(:source)).to receive(:copy_source_values)
      file.retrieve
    end
  end

  describe "#should_be_file?" do
    it "should have a method for determining if the file should be a normal file" do
      expect(file).to respond_to(:should_be_file?)
    end

    it "should be a file if :ensure is set to :file" do
      file[:ensure] = :file
      expect(file).to be_should_be_file
    end

    it "should be a file if :ensure is set to :present and the file exists as a normal file" do
      allow(file).to receive(:stat).and_return(double('stat', :ftype => "file"))
      file[:ensure] = :present
      expect(file).to be_should_be_file
    end

    it "should not be a file if :ensure is set to something other than :file" do
      file[:ensure] = :directory
      expect(file).to_not be_should_be_file
    end

    it "should not be a file if :ensure is set to :present and the file exists but is not a normal file" do
      allow(file).to receive(:stat).and_return(double('stat', :ftype => "directory"))
      file[:ensure] = :present
      expect(file).to_not be_should_be_file
    end

    it "should be a file if :ensure is not set and :content is" do
      file[:content] = "foo"
      expect(file).to be_should_be_file
    end

    it "should be a file if neither :ensure nor :content is set but the file exists as a normal file" do
      allow(file).to receive(:stat).and_return(double("stat", :ftype => "file"))
      expect(file).to be_should_be_file
    end

    it "should not be a file if neither :ensure nor :content is set but the file exists but not as a normal file" do
      allow(file).to receive(:stat).and_return(double("stat", :ftype => "directory"))
      expect(file).to_not be_should_be_file
    end
  end

  describe "#stat", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
    before do
      target = tmpfile('link_target')
      FileUtils.touch(target)
      Puppet::FileSystem.symlink(target, path)

      file[:target] = target
      file[:links] = :manage # so we always use :lstat
    end

    it "should stat the target if it is following links" do
      file[:links] = :follow

      expect(file.stat.ftype).to eq('file')
    end

    it "should stat the link if is it not following links" do
      file[:links] = :manage

      expect(file.stat.ftype).to eq('link')
    end

    it "should return nil if the file does not exist" do
      file[:path] = make_absolute('/foo/bar/baz/non-existent')

      expect(file.stat).to be_nil
    end

    it "should return nil if the file cannot be stat'ed" do
      dir = tmpfile('link_test_dir')
      child = File.join(dir, 'some_file')
      Dir.mkdir(dir)
      File.chmod(0, dir)

      file[:path] = child

      expect(file.stat).to be_nil

      # chmod it back so we can clean it up
      File.chmod(0777, dir)
    end

    it "should return nil if parts of path are no directories" do
      regular_file = tmpfile('ENOTDIR_test')
      FileUtils.touch(regular_file)
      impossible_child = File.join(regular_file, 'some_file')

      file[:path] = impossible_child
      expect(file.stat).to be_nil
    end

    it "should return the stat instance" do
      expect(file.stat).to be_a(File::Stat)
    end

    it "should cache the stat instance" do
      expect(file.stat.object_id).to eql(file.stat.object_id)
    end
  end

  describe "#write" do
    describe "when resource mode is supplied" do
      before do
        allow(file).to receive(:property_fix)
      end

      context "and writing temporary files" do
        before do
          allow(file).to receive(:write_temporary_file?).and_return(true)
        end

        it "should convert symbolic mode to int" do
          file[:mode] = 'oga=r'
          expect(Puppet::Util).to receive(:replace_file).with(file[:path], 0444, { :staging_location => nil, :validate_callback => nil })
          file.write
        end

        it "should support int modes" do
          file[:mode] = '0444'
          expect(Puppet::Util).to receive(:replace_file).with(file[:path], 0444, { :staging_location => nil, :validate_callback => nil })
          file.write
        end
      end

      context "and not writing temporary files" do
        before do
          allow(file).to receive(:write_temporary_file?).and_return(false)
        end

        it "should set a umask of 0" do
          file[:mode] = 'oga=r'
          expect(Puppet::Util).to receive(:withumask).with(0)
          file.write
        end

        it "should convert symbolic mode to int" do
          file[:mode] = 'oga=r'
          expect(File).to receive(:open).with(file[:path], anything, 0444)
          file.write
        end

        it "should support int modes" do
          file[:mode] = '0444'
          expect(File).to receive(:open).with(file[:path], anything, 0444)
          file.write
        end
      end
    end

    describe "when resource mode is not supplied" do
      context "and content is supplied" do
        it "should default to 0644 mode" do
          file = described_class.new(:path => path, :content => "file content")

          file.write file.parameter(:content)

          expect(File.stat(file[:path]).mode & 0777).to eq(0644)
        end
      end

      context "and no content is supplied" do
        it "should use puppet's default umask of 022" do
          file = described_class.new(:path => path)

          umask_from_the_user = 0777
          Puppet::Util.withumask(umask_from_the_user) do
            file.write
          end

          expect(File.stat(file[:path]).mode & 0777).to eq(0644)
        end
      end
    end
  end

  describe "#write_temporary_file?" do
    it "should be true if the file has specified content" do
      file[:content] = 'some content'

      expect(file.send(:write_temporary_file?)).to be_truthy
    end

    it "should be true if the file has specified source" do
      file[:source] = File.expand_path('/tmp/foo')

      expect(file.send(:write_temporary_file?)).to be_truthy
    end

    it "should be false if the file has neither content nor source" do
      expect(file.send(:write_temporary_file?)).to be_falsey
    end

    context "and staging_location is provided" do
      it "should write the file first to the staging location" do
        file[:content] = 'some content'
        file[:staging_location] = Dir.tmpdir()
        expect(Puppet::Util).to receive(:replace_file).with(file[:path], nil, { staging_location: Dir.tmpdir(), validate_callback: nil })
        file.write
      end
    end
  end

  describe "#property_fix" do
    {
      :mode     => '0777',
      :owner    => 'joeuser',
      :group    => 'joeusers',
      :seluser  => 'seluser',
      :selrole  => 'selrole',
      :seltype  => 'seltype',
      :selrange => 'selrange'
    }.each do |name,value|
      it "should sync the #{name} property if it's not in sync" do
        file[name] = value

        prop = file.property(name)
        expect(prop).to receive(:retrieve)
        expect(prop).to receive(:safe_insync?).and_return(false)
        expect(prop).to receive(:sync)

        file.send(:property_fix)
      end
    end
  end

  describe "when autorequiring" do
    describe "target" do
      it "should require file resource when specified with the target property", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
        file = described_class.new(:path => File.expand_path("/foo"), :ensure => :directory)
        link = described_class.new(:path => File.expand_path("/bar"), :ensure => :link, :target => File.expand_path("/foo"))
        catalog.add_resource file
        catalog.add_resource link
        reqs = link.autorequire
        expect(reqs.size).to eq(1)
        expect(reqs[0].source).to eq(file)
        expect(reqs[0].target).to eq(link)
      end

      it "should require file resource when specified with the ensure property" do
        file = described_class.new(:path => File.expand_path("/foo"), :ensure => :directory)
        link = described_class.new(:path => File.expand_path("/bar"), :ensure => File.expand_path("/foo"))
        catalog.add_resource file
        catalog.add_resource link
        reqs = link.autorequire
        expect(reqs.size).to eq(1)
        expect(reqs[0].source).to eq(file)
        expect(reqs[0].target).to eq(link)
      end

      it "should not require target if target is not managed", :if => described_class.defaultprovider.feature?(:manages_symlinks) do
        link = described_class.new(:path => File.expand_path('/foo'), :ensure => :link, :target => '/bar')
        catalog.add_resource link
        expect(link.autorequire.size).to eq(0)
      end
    end

    describe "directories" do
      it "should autorequire its parent directory" do
        dir = described_class.new(:path => File.dirname(path))
        catalog.add_resource file
        catalog.add_resource dir
        reqs = file.autorequire
        expect(reqs[0].source).to eq(dir)
        expect(reqs[0].target).to eq(file)
      end

      it "should autorequire its nearest ancestor directory" do
        dir = described_class.new(:path => File.dirname(path))
        grandparent = described_class.new(:path => File.dirname(File.dirname(path)))
        catalog.add_resource file
        catalog.add_resource dir
        catalog.add_resource grandparent
        reqs = file.autorequire
        expect(reqs.length).to eq(1)
        expect(reqs[0].source).to eq(dir)
        expect(reqs[0].target).to eq(file)
      end

      it "should not autorequire anything when there is no nearest ancestor directory" do
        catalog.add_resource file
        expect(file.autorequire).to be_empty
      end

      it "should not autorequire its parent dir if its parent dir is itself" do
        file[:path] = File.expand_path('/')
        catalog.add_resource file
        expect(file.autorequire).to be_empty
      end

      describe "on Windows systems", :if => Puppet::Util::Platform.windows? do
        describe "when using UNC filenames" do
          it "should autorequire its parent directory" do
            file[:path] = '//localhost/foo/bar/baz'
            dir = described_class.new(:path => "//localhost/foo/bar")
            catalog.add_resource file
            catalog.add_resource dir
            reqs = file.autorequire
            expect(reqs[0].source).to eq(dir)
            expect(reqs[0].target).to eq(file)
          end

          it "should autorequire its nearest ancestor directory" do
            file = described_class.new(:path => "//localhost/foo/bar/baz/qux")
            dir = described_class.new(:path => "//localhost/foo/bar/baz")
            grandparent = described_class.new(:path => "//localhost/foo/bar")
            catalog.add_resource file
            catalog.add_resource dir
            catalog.add_resource grandparent
            reqs = file.autorequire
            expect(reqs.length).to eq(1)
            expect(reqs[0].source).to eq(dir)
            expect(reqs[0].target).to eq(file)
          end

          it "should not autorequire anything when there is no nearest ancestor directory" do
            file = described_class.new(:path => "//localhost/foo/bar/baz/qux")
            catalog.add_resource file
            expect(file.autorequire).to be_empty
          end

          it "should not autorequire its parent dir if its parent dir is itself" do
            file = described_class.new(:path => "//localhost/foo")
            catalog.add_resource file
            puts file.autorequire
            expect(file.autorequire).to be_empty
          end
        end
      end
    end
  end

  describe "when managing links", :if => Puppet.features.manages_symlinks? do
    require 'tempfile'

    before :each do
      Dir.mkdir(path)
      @target = File.join(path, "target")
      @link   = File.join(path, "link")

      target = described_class.new(
        :ensure => :file, :path => @target,
        :catalog => catalog, :content => 'yayness',
        :mode => '0644')
      catalog.add_resource target

      @link_resource = described_class.new(
        :ensure => :link, :path => @link,
        :target => @target, :catalog => catalog,
        :mode => '0755')
      catalog.add_resource @link_resource

      # to prevent the catalog from trying to write state.yaml
      allow(Puppet::Util::Storage).to receive(:store)
    end

    it "should preserve the original file mode and ignore the one set by the link" do
      @link_resource[:links] = :manage # default
      catalog.apply

      # I convert them to strings so they display correctly if there's an error.
      expect((Puppet::FileSystem.stat(@target).mode & 007777).to_s(8)).to eq('644')
    end

    it "should manage the mode of the followed link" do
      if Puppet::Util::Platform.windows?
        skip "Windows cannot presently manage the mode when following symlinks"
      else
        @link_resource[:links] = :follow
        catalog.apply

        expect((Puppet::FileSystem.stat(@target).mode & 007777).to_s(8)).to eq('755')
      end
    end
  end

  describe 'when using source' do
    # different UTF-8 widths
    # 1-byte A
    # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
    # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
    # 4-byte <U+070E> - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
    let (:mixed_utf8) { "A\u06FF\u16A0\u{2070E}" } # Aۿᚠ<U+070E>

    it 'should allow UTF-8 characters and return a UTF-8 uri' do
      filename = "/bar #{mixed_utf8}"
      source = "puppet://foo#{filename}"
      file[:source] = source

      # intercept the indirector call to provide back mocked metadata for the given URI
      metadata = double('metadata', :source => source)
      expect(metadata).to receive(:source=)
      expect(Puppet::FileServing::Metadata.indirection).to receive(:find).with(source, anything).and_return(metadata)

      uri = file.parameters[:source].uri
      expect(Puppet::Util.uri_unescape(uri.path)).to eq(filename)
      expect(uri.path.encoding).to eq(Encoding::UTF_8)
    end

    matcher :request_key do |expected|
      match do |actual|
        values_match? expected, actual.key
      end
    end

    it 'should allow UTF-8 characters inside the indirector / terminus code' do
      filename = "/bar #{mixed_utf8}"
      source = "puppet://foo#{filename}"
      file[:source] = source

      # for this test to properly trigger previously errant behavior, the code for
      # Puppet::FileServing::Metadata.indirection.find must run and produce an
      # instance of Puppet::Indirector::FileMetadata::Rest that can be amended
      metadata = double('metadata', :source => source)
      expect(metadata).to receive(:source=)
      require 'puppet/indirector/file_metadata/rest'
      expect_any_instance_of(Puppet::Indirector::FileMetadata::Rest).to receive(:find).with(request_key(filename[1..-1])).and_return(metadata)

      uri = file.parameters[:source].uri
      expect(Puppet::Util.uri_unescape(uri.path)).to eq(filename)
      expect(uri.path.encoding).to eq(Encoding::UTF_8)
    end
  end

  describe "when using source" do
    let(:source) { tmpfile('file_source') }

    before do
      file[:source] = source
    end

    Puppet::Type::File::ParameterChecksum.value_collection.values.reject {|v| v == :none}.each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        before do
          file[:checksum] = checksum_type
        end

        it 'should validate' do
          expect { file.validate }.to_not raise_error
        end

        it 'should fail on an invalid checksum_value' do
          file[:checksum_value] = ''
          expect { file.validate }.to raise_error(Puppet::Error, "Checksum value '' is not a valid checksum type #{checksum_type}")
        end

        it 'should validate a valid checksum_value' do
          file[:checksum_value] = CHECKSUM_VALUES[checksum_type]
          expect { file.validate }.to_not raise_error
        end

        it 'fails if the checksum_value parameter and written file do not match' do
          skip if checksum_type =~ /^(ctime|mtime)/

          pending("PUP-10368")

          Puppet::FileSystem.touch(source)
          file[:checksum_value] = INVALID_CHECKSUM_VALUES[checksum_type]

          expect {
            file.property(:checksum_value).sync
          }.to raise_error(Puppet::Error, /File written to disk did not match desired checksum/)

          expect(Puppet::FileSystem).to_not be_exist(file[:path])
        end

        it 'replaces a file from a source when the checksum matches' do
          Puppet::FileSystem.touch(source)
          file[:checksum_value] = CHECKSUM_VALUES[checksum_type]

          file.property(:checksum_value).sync
          checksum = file.parameter(:checksum).sum_file(file[:path])

          if checksum_type =~ /^(ctime|mtime)/
            # file on disk ctime/mtime will be later than expected time
            expect(checksum).to match(/{#{checksum_type}}/)
          else
            expect(checksum).to eq("{#{checksum_type}}#{file[:checksum_value]}")
          end
        end
      end
    end

    describe "on Windows when source_permissions is `use`" do
      before :each do
        allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)

        file[:source_permissions] = "use"
      end
      let(:err_message) { "Copying owner/mode/group from the" <<
                          " source file on Windows is not supported;" <<
                          " use source_permissions => ignore." }

      it "should issue error when retrieving" do
        expect { file.retrieve }.to raise_error(err_message)
      end

      it "should issue error when retrieving if only user is unspecified" do
        file[:group] = 2
        file[:mode] = "0003"

        expect { file.retrieve }.to raise_error(err_message)
      end

      it "should issue error when retrieving if only group is unspecified" do
        file[:owner] = 1
        file[:mode] = "0003"

        expect { file.retrieve }.to raise_error(err_message)
      end

      it "should issue error when retrieving if only mode is unspecified" do
        file[:owner] = 1
        file[:group] = 2

        expect { file.retrieve }.to raise_error(err_message)
      end

      it "should issue warning when retrieve if group, owner, and mode are all specified" do
        file[:owner] = 1
        file[:group] = 2
        file[:mode] = "0003"

        expect(file.parameter(:source)).to receive(:copy_source_values)
        expect(file).to receive(:warning).with(err_message)
        expect { file.retrieve }.not_to raise_error
      end
    end

    describe "with checksum 'none'" do
      before do
        file[:checksum] = :none
      end

      it 'should raise an exception when validating' do
        expect { file.validate }.to raise_error(/You cannot specify source when using checksum 'none'/)
      end
    end
  end

  describe "when using content" do
    before :each do
      file[:content] = FILE_CONTENT
    end

    (Puppet::Type::File::ParameterChecksum.value_collection.values - SOURCE_ONLY_CHECKSUMS).each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        before do
          file[:checksum] = checksum_type
        end

        it 'should validate' do
          expect { file.validate }.to_not raise_error
        end

        it 'should fail on an invalid checksum_value' do
          file[:checksum_value] = ''
          expect { file.validate }.to raise_error(Puppet::Error, "Checksum value '' is not a valid checksum type #{checksum_type}")
        end

        it 'should validate a valid checksum_value' do
          file[:checksum_value] = CHECKSUM_VALUES[checksum_type]
          expect { file.validate }.to_not raise_error
        end

        it 'fails if the checksum_value parameter and written file do not match' do
          pending("PUP-10368")

          file[:checksum_value] = INVALID_CHECKSUM_VALUES[checksum_type]

          expect {
            file.property(:content).sync
          }.to raise_error(Puppet::Error, /File written to disk did not match desired checksum/)

          expect(Puppet::FileSystem).to_not be_exist(file[:path])
        end

        it 'replaces a file from content when the checksum matches' do
          file[:checksum_value] = CHECKSUM_VALUES[checksum_type]

          file.property(:content).sync
          checksum = file.parameter(:checksum).sum_file(file[:path])

          if checksum_type =~ /^(ctime|mtime)/
            # file on disk ctime/mtime will be later than expected time
            expect(checksum).to match(/{#{checksum_type}}/)
          else
            expect(checksum).to eq("{#{checksum_type}}#{file[:checksum_value]}")
          end
        end
      end
    end

    SOURCE_ONLY_CHECKSUMS.each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        it 'should raise an exception when validating' do
          file[:checksum] = checksum_type

          expect { file.validate }.to raise_error(/You cannot specify content when using checksum '#{checksum_type}'/)
        end
      end
    end
  end

  describe "when checksum is none" do
    before do
      file[:checksum] = :none
    end

    it 'should validate' do
      expect { file.validate }.to_not raise_error
    end

    it 'should fail on an invalid checksum_value' do
      file[:checksum_value] = 'boo'
      expect { file.validate }.to raise_error(Puppet::Error, "Checksum value 'boo' is not a valid checksum type none")
    end

    it 'should validate a valid checksum_value' do
      file[:checksum_value] = ''
      expect { file.validate }.to_not raise_error
    end

    it 'writes a file' do
      file[:ensure] = :file
      file.property(:ensure).sync

      expect(file.parameter(:checksum).sum_file(file[:path])).to eq('{none}')
    end
  end

  describe "when auditing" do
    before :each do
      # to prevent the catalog from trying to write state.yaml
      allow(Puppet::Util::Storage).to receive(:store)
    end

    it "should not fail if creating a new file if group is not set" do
      file = described_class.new(:path => path, :audit => 'all', :content => 'content')
      catalog.add_resource(file)

      report = catalog.apply.report

      expect(report.resource_statuses["File[#{path}]"]).not_to be_failed
      expect(File.read(path)).to eq('content')
    end

    it "should not log errors if creating a new file with ensure present and no content" do
      file[:audit]  = 'content'
      file[:ensure] = 'present'
      catalog.add_resource(file)

      catalog.apply

      expect(Puppet::FileSystem.exist?(path)).to be_truthy
      expect(@logs).not_to be_any { |l|
        # the audit metaparameter is deprecated and logs a warning
        l.level != :notice
      }
    end
  end

  describe "when specifying both source and checksum" do
    it 'should use the specified checksum when source is first' do
      file[:source] = File.expand_path('/foo')
      file[:checksum] = :md5lite

      expect(file[:checksum]).to eq(:md5lite)
    end

    it 'should use the specified checksum when source is last' do
      file[:checksum] = :md5lite
      file[:source] = File.expand_path('/foo')

      expect(file[:checksum]).to eq(:md5lite)
    end
  end

  describe "when validating" do
    [[:source, :target], [:source, :content], [:target, :content]].each do |prop1,prop2|
      it "should fail if both #{prop1} and #{prop2} are specified" do
          file[prop1] = prop1 == :source ? File.expand_path("prop1 value") : "prop1 value"
          file[prop2] = "prop2 value"
        expect do
          file.validate
        end.to raise_error(Puppet::Error, /You cannot specify more than one of/)
      end
    end
  end
end
