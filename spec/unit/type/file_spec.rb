#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:file) do
  include PuppetSpec::Files

  let(:path) { tmpfile('file_testing') }
  let(:file) { described_class.new(:path => path, :catalog => catalog) }
  let(:provider) { file.provider }
  let(:catalog) { Puppet::Resource::Catalog.new }

  before do
    @real_posix = Puppet.features.posix?
    Puppet.features.stubs("posix?").returns(true)
  end

  describe "the path parameter" do
    describe "on POSIX systems", :if => Puppet.features.posix? do
      it "should remove trailing slashes" do
        file[:path] = "/foo/bar/baz/"
        file[:path].should == "/foo/bar/baz"
      end

      it "should remove double slashes" do
        file[:path] = "/foo/bar//baz"
        file[:path].should == "/foo/bar/baz"
      end

      it "should remove trailing double slashes" do
        file[:path] = "/foo/bar/baz//"
        file[:path].should == "/foo/bar/baz"
      end

      it "should leave a single slash alone" do
        file[:path] = "/"
        file[:path].should == "/"
      end

      it "should accept a double-slash at the start of the path" do
        expect {
          file[:path] = "//tmp/xxx"
          # REVISIT: This should be wrong, later.  See the next test.
          # --daniel 2011-01-31
          file[:path].should == '/tmp/xxx'
        }.should_not raise_error
      end

      # REVISIT: This is pending, because I don't want to try and audit the
      # entire codebase to make sure we get this right.  POSIX treats two (and
      # exactly two) '/' characters at the start of the path specially.
      #
      # See sections 3.2 and 4.11, which allow DomainOS to be all special like
      # and still have the POSIX branding and all. --daniel 2011-01-31
      it "should preserve the double-slash at the start of the path"
    end

    describe "on Windows systems", :if => Puppet.features.microsoft_windows? do
      it "should remove trailing slashes" do
        file[:path] = "X:/foo/bar/baz/"
        file[:path].should == "X:/foo/bar/baz"
      end

      it "should remove double slashes" do
        file[:path] = "X:/foo/bar//baz"
        file[:path].should == "X:/foo/bar/baz"
      end

      it "should remove trailing double slashes" do
        file[:path] = "X:/foo/bar/baz//"
        file[:path].should == "X:/foo/bar/baz"
      end

      it "should leave a drive letter with a slash alone", :'fails_on_ruby_1.9.2' => true do
        file[:path] = "X:/"
        file[:path].should == "X:/"
      end

      it "should not accept a drive letter without a slash", :'fails_on_ruby_1.9.2' => true do
        lambda { file[:path] = "X:" }.should raise_error(/File paths must be fully qualified/)
      end

      describe "when using UNC filenames", :if => Puppet.features.microsoft_windows?, :'fails_on_ruby_1.9.2' => true do
        before :each do
          pending("UNC file paths not yet supported")
        end

        it "should remove trailing slashes" do
          file[:path] = "//server/foo/bar/baz/"
          file[:path].should == "//server/foo/bar/baz"
        end

        it "should remove double slashes" do
          file[:path] = "//server/foo/bar//baz"
          file[:path].should == "//server/foo/bar/baz"
        end

        it "should remove trailing double slashes" do
          file[:path] = "//server/foo/bar/baz//"
          file[:path].should == "//server/foo/bar/baz"
        end

        it "should remove a trailing slash from a sharename" do
          file[:path] = "//server/foo/"
          file[:path].should == "//server/foo"
        end

        it "should not modify a sharename" do
          file[:path] = "//server/foo"
          file[:path].should == "//server/foo"
        end
      end
    end
  end

  describe "the backup parameter" do
    [false, 'false', :false].each do |value|
      it "should disable backup if the value is #{value.inspect}" do
        file[:backup] = value
        file[:backup].should == false
      end
    end

    [true, 'true', '.puppet-bak'].each do |value|
      it "should use .puppet-bak if the value is #{value.inspect}" do
        file[:backup] = value
        file[:backup].should == '.puppet-bak'
      end
    end

    it "should use the provided value if it's any other string" do
      file[:backup] = "over there"
      file[:backup].should == "over there"
    end

    it "should fail if backup is set to anything else" do
      expect do
        file[:backup] = 97
      end.to raise_error(Puppet::Error, /Invalid backup type 97/)
    end
  end

  describe "the recurse parameter" do
    it "should default to recursion being disabled" do
      file[:recurse].should be_false
    end

    [true, "true", 10, "inf", "remote"].each do |value|
      it "should consider #{value} to enable recursion" do
        file[:recurse] = value
        file[:recurse].should be_true
      end
    end

    [false, "false", 0].each do |value|
      it "should consider #{value} to disable recursion" do
        file[:recurse] = value
        file[:recurse].should be_false
      end
    end

    it "should warn if recurse is specified as a number" do
      file[:recurse] = 3
      message = /Setting recursion depth with the recurse parameter is now deprecated, please use recurselimit/
      @logs.find { |log| log.level == :warning and log.message =~ message}.should_not be_nil
    end
  end

  describe "the recurselimit parameter" do
    it "should accept integers" do
      file[:recurselimit] = 12
      file[:recurselimit].should == 12
    end

    it "should munge string numbers to number numbers" do
      file[:recurselimit] = '12'
      file[:recurselimit].should == 12
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
        file[:replace].should == :true
      end
    end

    [false, :false, :no].each do |value|
      it "should consider #{value} to be false" do
        file[:replace] = value
        file[:replace].should == :false
      end
    end
  end

  describe "#[]" do
    it "should raise an exception" do
      expect do
        described_class['anything']
      end.to raise_error("Global resource access is deprecated")
    end
  end

  describe ".instances" do
    it "should return an empty array" do
      described_class.instances.should == []
    end
  end

  describe "#asuser" do
    before :each do
      # Mocha won't let me just stub SUIDManager.asuser to yield and return,
      # but it will do exactly that if we're not root.
      Puppet.features.stubs(:root?).returns false
    end

    it "should return the desired owner if they can write to the parent directory" do
      file[:owner] = 1001
      FileTest.stubs(:writable?).with(File.dirname file[:path]).returns true

      file.asuser.should == 1001
    end

    it "should return nil if the desired owner can't write to the parent directory" do
      file[:owner] = 1001
      FileTest.stubs(:writable?).with(File.dirname file[:path]).returns false

      file.asuser.should == nil
    end

    it "should return nil if not managing owner" do
      file.asuser.should == nil
    end
  end

  describe "#bucket" do
    it "should return nil if backup is off" do
      file[:backup] = false
      file.bucket.should == nil
    end

    it "should not return a bucket if using a file extension for backup" do
      file[:backup] = '.backup'

      file.bucket.should == nil
    end

    it "should return the default filebucket if using the 'puppet' filebucket" do
      file[:backup] = 'puppet'
      bucket = stub('bucket')
      file.stubs(:default_bucket).returns bucket

      file.bucket.should == bucket
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

      file.bucket.should == filebucket.bucket
    end
  end

  describe "#asuser" do
    before :each do
      # Mocha won't let me just stub SUIDManager.asuser to yield and return,
      # but it will do exactly that if we're not root.
      Puppet.features.stubs(:root?).returns false
    end

    it "should return the desired owner if they can write to the parent directory" do
      file[:owner] = 1001
      FileTest.stubs(:writable?).with(File.dirname file[:path]).returns true

      file.asuser.should == 1001
    end

    it "should return nil if the desired owner can't write to the parent directory" do
      file[:owner] = 1001
      FileTest.stubs(:writable?).with(File.dirname file[:path]).returns false

      file.asuser.should == nil
    end

    it "should return nil if not managing owner" do
      file.asuser.should == nil
    end
  end

  describe "#bucket" do
    it "should return nil if backup is off" do
      file[:backup] = false
      file.bucket.should == nil
    end

    it "should return nil if using a file extension for backup" do
      file[:backup] = '.backup'

      file.bucket.should == nil
    end

    it "should return the default filebucket if using the 'puppet' filebucket" do
      file[:backup] = 'puppet'
      bucket = stub('bucket')
      file.stubs(:default_bucket).returns bucket

      file.bucket.should == bucket
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

      file.bucket.should == filebucket.bucket
    end
  end

  describe "#exist?" do
    it "should be considered existent if it can be stat'ed" do
      file.expects(:stat).returns mock('stat')
      file.must be_exist
    end

    it "should be considered nonexistent if it can not be stat'ed" do
      file.expects(:stat).returns nil
      file.must_not be_exist
    end
  end

  describe "#eval_generate" do
    before do
      @graph = stub 'graph', :add_edge => nil
      catalog.stubs(:relationship_graph).returns @graph
    end

    it "should recurse if recursion is enabled" do
      resource = stub('resource', :[] => 'resource')
      file.expects(:recurse).returns [resource]

      file[:recurse] = true

      file.eval_generate.should == [resource]
    end

    it "should not recurse if recursion is disabled" do
      file.expects(:recurse).never

      file[:recurse] = false

      file.eval_generate.should == []
    end
  end

  describe "#ancestors" do
    it "should return the ancestors of the file, in ascending order" do
      file = described_class.new(:path => make_absolute("/tmp/foo/bar/baz/qux"))

      pieces = %W[#{make_absolute('/')} tmp foo bar baz]

      ancestors = file.ancestors

      ancestors.should_not be_empty
      ancestors.reverse.each_with_index do |path,i|
        path.should == File.join(*pieces[0..i])
      end
    end
  end

  describe "#flush" do
    it "should flush all properties that respond to :flush" do
      file[:source] = File.expand_path(__FILE__)
      file.parameter(:source).expects(:flush)
      file.flush
    end

    it "should reset its stat reference" do
      FileUtils.touch(path)
      stat1 = file.stat

      file.stat.should equal(stat1)

      file.flush

      file.stat.should_not equal(stat1)
    end
  end

  describe "#initialize" do
    it "should remove a trailing slash from the title to create the path" do
      title = File.expand_path("/abc/\n\tdef/")
      file = described_class.new(:title => title)
      file[:path].should == title
    end

    it "should set a desired 'ensure' value if none is set and 'content' is set" do
      file = described_class.new(:path => path, :content => "/foo/bar")
      file[:ensure].should == :file
    end

    it "should set a desired 'ensure' value if none is set and 'target' is set" do
      file = described_class.new(:path => path, :target => File.expand_path(__FILE__))
      file[:ensure].should == :symlink
    end
  end

  describe "#mark_children_for_purging" do
    it "should set each child's ensure to absent" do
      paths = %w[foo bar baz]
      children = paths.inject({}) do |children,child|
        children.merge child => described_class.new(:path => File.join(path, child), :ensure => :present)
      end

      file.mark_children_for_purging(children)

      children.length.should == 3
      children.values.each do |child|
        child[:ensure].should == :absent
      end
    end

    it "should skip children which have a source" do
      child = described_class.new(:path => path, :ensure => :present, :source => File.expand_path(__FILE__))

      file.mark_children_for_purging('foo' => child)

      child[:ensure].should == :present
    end
  end

  describe "#newchild" do
    it "should create a new resource relative to the parent" do
      child = file.newchild('bar')

      child.should be_a(described_class)
      child[:path].should == File.join(file[:path], 'bar')
    end

    {
      :ensure => :present,
      :recurse => true,
      :recurselimit => 5,
      :target => "some_target",
      :source => File.expand_path("some_source"),
    }.each do |param, value|
      it "should omit the #{param} parameter" do
        # Make a new file, because we have to set the param at initialization
        # or it wouldn't be copied regardless.
        file = described_class.new(:path => path, param => value)
        child = file.newchild('bar')
        child[param].should_not == value
      end
    end

    it "should copy all of the parent resource's 'should' values that were set at initialization" do
      parent = described_class.new(:path => path, :owner => 'root', :group => 'wheel')

      child = parent.newchild("my/path")

      child[:owner].should == 'root'
      child[:group].should == 'wheel'
    end

    it "should not copy default values to the new child" do
      child = file.newchild("my/path")
      child.original_parameters.should_not include(:backup)
    end

    it "should not copy values to the child which were set by the source" do
      source = File.expand_path(__FILE__)
      file[:source] = source
      metadata = stub 'metadata', :owner => "root", :group => "root", :mode => 0755, :ftype => "file", :checksum => "{md5}whatever", :source => source
      file.parameter(:source).stubs(:metadata).returns metadata

      file.parameter(:source).copy_source_values

      file.class.expects(:new).with { |params| params[:group].nil? }
      file.newchild("my/path")
    end
  end

  describe "#purge?" do
    it "should return false if purge is not set" do
      file.must_not be_purge
    end

    it "should return true if purge is set to true" do
      file[:purge] = true

      file.must be_purge
    end

    it "should return false if purge is set to false" do
      file[:purge] = false

      file.must_not be_purge
    end
  end

  describe "#recurse" do
    before do
      file[:recurse] = true
      @metadata = Puppet::FileServing::Metadata
    end

    describe "and a source is set" do
      it "should pass the already-discovered resources to recurse_remote" do
        file[:source] = File.expand_path(__FILE__)
        file.stubs(:recurse_local).returns(:foo => "bar")
        file.expects(:recurse_remote).with(:foo => "bar").returns []
        file.recurse
      end
    end

    describe "and a target is set" do
      it "should use recurse_link" do
        file[:target] = File.expand_path(__FILE__)
        file.stubs(:recurse_local).returns(:foo => "bar")
        file.expects(:recurse_link).with(:foo => "bar").returns []
        file.recurse
      end
    end

    it "should use recurse_local if recurse is not remote" do
      file.expects(:recurse_local).returns({})
      file.recurse
    end

    it "should not use recurse_local if recurse is remote" do
      file[:recurse] = :remote
      file.expects(:recurse_local).never
      file.recurse
    end

    it "should return the generated resources as an array sorted by file path" do
      one = stub 'one', :[] => "/one"
      two = stub 'two', :[] => "/one/two"
      three = stub 'three', :[] => "/three"
      file.expects(:recurse_local).returns(:one => one, :two => two, :three => three)
      file.recurse.should == [one, two, three]
    end

    describe "and purging is enabled" do
      before do
        file[:purge] = true
      end

      it "should mark each file for removal" do
        local = described_class.new(:path => path, :ensure => :present)
        file.expects(:recurse_local).returns("local" => local)

        file.recurse
        local[:ensure].should == :absent
      end

      it "should not remove files that exist in the remote repository" do
        file[:source] = File.expand_path(__FILE__)
        file.expects(:recurse_local).returns({})

        remote = described_class.new(:path => path, :source => File.expand_path(__FILE__), :ensure => :present)

        file.expects(:recurse_remote).with { |hash| hash["remote"] = remote }

        file.recurse

        remote[:ensure].should_not == :absent
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

      file.remove_less_specific_files([foo, bar, baz]).should == [baz]
    end
  end

  describe "#remove_less_specific_files" do
    it "should remove any nested files that are already in the catalog" do
      foo = described_class.new :path => File.join(file[:path], 'foo')
      bar = described_class.new :path => File.join(file[:path], 'bar')
      baz = described_class.new :path => File.join(file[:path], 'baz')

      catalog.add_resource(foo)
      catalog.add_resource(bar)

      file.remove_less_specific_files([foo, bar, baz]).should == [baz]
    end

  end

  describe "#recurse?" do
    it "should be true if recurse is true" do
      file[:recurse] = true
      file.must be_recurse
    end

    it "should be true if recurse is remote" do
      file[:recurse] = :remote
      file.must be_recurse
    end

    it "should be false if recurse is false" do
      file[:recurse] = false
      file.must_not be_recurse
    end
  end

  describe "#recurse_link" do
    before do
      @first = stub 'first', :relative_path => "first", :full_path => "/my/first", :ftype => "directory"
      @second = stub 'second', :relative_path => "second", :full_path => "/my/second", :ftype => "file"

      @resource = stub 'file', :[]= => nil
    end

    it "should pass its target to the :perform_recursion method" do
      file[:target] = "mylinks"
      file.expects(:perform_recursion).with("mylinks").returns [@first]
      file.stubs(:newchild).returns @resource
      file.recurse_link({})
    end

    it "should ignore the recursively-found '.' file and configure the top-level file to create a directory" do
      @first.stubs(:relative_path).returns "."
      file[:target] = "mylinks"
      file.expects(:perform_recursion).with("mylinks").returns [@first]
      file.stubs(:newchild).never
      file.expects(:[]=).with(:ensure, :directory)
      file.recurse_link({})
    end

    it "should create a new child resource for each generated metadata instance's relative path that doesn't already exist in the children hash" do
      file.expects(:perform_recursion).returns [@first, @second]
      file.expects(:newchild).with(@first.relative_path).returns @resource
      file.recurse_link("second" => @resource)
    end

    it "should not create a new child resource for paths that already exist in the children hash" do
      file.expects(:perform_recursion).returns [@first]
      file.expects(:newchild).never
      file.recurse_link("first" => @resource)
    end

    it "should set the target to the full path of discovered file and set :ensure to :link if the file is not a directory" do
      file.stubs(:perform_recursion).returns [@first, @second]
      file.recurse_link("first" => @resource, "second" => file)

      file[:ensure].should == :link
      file[:target].should == "/my/second"
    end

    it "should :ensure to :directory if the file is a directory" do
      file.stubs(:perform_recursion).returns [@first, @second]
      file.recurse_link("first" => file, "second" => @resource)

      file[:ensure].should == :directory
    end

    it "should return a hash with both created and existing resources with the relative paths as the hash keys" do
      file.expects(:perform_recursion).returns [@first, @second]
      file.stubs(:newchild).returns file
      file.recurse_link("second" => @resource).should == {"second" => @resource, "first" => file}
    end
  end

  describe "#recurse_local" do
    before do
      @metadata = stub 'metadata', :relative_path => "my/file"
    end

    it "should pass its path to the :perform_recursion method" do
      file.expects(:perform_recursion).with(file[:path]).returns [@metadata]
      file.stubs(:newchild)
      file.recurse_local
    end

    it "should return an empty hash if the recursion returns nothing" do
      file.expects(:perform_recursion).returns nil
      file.recurse_local.should == {}
    end

    it "should create a new child resource with each generated metadata instance's relative path" do
      file.expects(:perform_recursion).returns [@metadata]
      file.expects(:newchild).with(@metadata.relative_path).returns "fiebar"
      file.recurse_local
    end

    it "should not create a new child resource for the '.' directory" do
      @metadata.stubs(:relative_path).returns "."

      file.expects(:perform_recursion).returns [@metadata]
      file.expects(:newchild).never
      file.recurse_local
    end

    it "should return a hash of the created resources with the relative paths as the hash keys" do
      file.expects(:perform_recursion).returns [@metadata]
      file.expects(:newchild).with("my/file").returns "fiebar"
      file.recurse_local.should == {"my/file" => "fiebar"}
    end

    it "should set checksum_type to none if this file checksum is none" do
      file[:checksum] = :none
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |path,params| params[:checksum_type] == :none }.returns [@metadata]
      file.expects(:newchild).with("my/file").returns "fiebar"
      file.recurse_local
    end
  end

  describe "#recurse_remote" do
    before do
      file[:source] = "puppet://foo/bar"

      @first = Puppet::FileServing::Metadata.new("/my", :relative_path => "first")
      @second = Puppet::FileServing::Metadata.new("/my", :relative_path => "second")
      @first.stubs(:ftype).returns "directory"
      @second.stubs(:ftype).returns "directory"

      @parameter = stub 'property', :metadata= => nil
      @resource = stub 'file', :[]= => nil, :parameter => @parameter
    end

    it "should pass its source to the :perform_recursion method" do
      data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
      file.expects(:perform_recursion).with("puppet://foo/bar").returns [data]
      file.stubs(:newchild).returns @resource
      file.recurse_remote({})
    end

    it "should not recurse when the remote file is not a directory" do
      data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => ".")
      data.stubs(:ftype).returns "file"
      file.expects(:perform_recursion).with("puppet://foo/bar").returns [data]
      file.expects(:newchild).never
      file.recurse_remote({})
    end

    it "should set the source of each returned file to the searched-for URI plus the found relative path" do
      @first.expects(:source=).with File.join("puppet://foo/bar", @first.relative_path)
      file.expects(:perform_recursion).returns [@first]
      file.stubs(:newchild).returns @resource
      file.recurse_remote({})
    end

    it "should create a new resource for any relative file paths that do not already have a resource" do
      file.stubs(:perform_recursion).returns [@first]
      file.expects(:newchild).with("first").returns @resource
      file.recurse_remote({}).should == {"first" => @resource}
    end

    it "should not create a new resource for any relative file paths that do already have a resource" do
      file.stubs(:perform_recursion).returns [@first]
      file.expects(:newchild).never
      file.recurse_remote("first" => @resource)
    end

    it "should set the source of each resource to the source of the metadata" do
      file.stubs(:perform_recursion).returns [@first]
      @resource.stubs(:[]=)
      @resource.expects(:[]=).with(:source, File.join("puppet://foo/bar", @first.relative_path))
      file.recurse_remote("first" => @resource)
    end

    # LAK:FIXME This is a bug, but I can't think of a fix for it.  Fortunately it's already
    # filed, and when it's fixed, we'll just fix the whole flow.
    it "should set the checksum type to :md5 if the remote file is a file" do
      @first.stubs(:ftype).returns "file"
      file.stubs(:perform_recursion).returns [@first]
      @resource.stubs(:[]=)
      @resource.expects(:[]=).with(:checksum, :md5)
      file.recurse_remote("first" => @resource)
    end

    it "should store the metadata in the source property for each resource so the source does not have to requery the metadata" do
      file.stubs(:perform_recursion).returns [@first]
      @resource.expects(:parameter).with(:source).returns @parameter

      @parameter.expects(:metadata=).with(@first)

      file.recurse_remote("first" => @resource)
    end

    it "should not create a new resource for the '.' file" do
      @first.stubs(:relative_path).returns "."
      file.stubs(:perform_recursion).returns [@first]

      file.expects(:newchild).never

      file.recurse_remote({})
    end

    it "should store the metadata in the main file's source property if the relative path is '.'" do
      @first.stubs(:relative_path).returns "."
      file.stubs(:perform_recursion).returns [@first]

      file.parameter(:source).expects(:metadata=).with @first

      file.recurse_remote("first" => @resource)
    end

    describe "and multiple sources are provided" do
      let(:sources) do
        h = {}
        %w{/a /b /c /d}.each do |key|
          h[key] = URI.unescape(Puppet::Util.path_to_uri(File.expand_path(key)).to_s)
        end
        h
      end

      describe "and :sourceselect is set to :first" do
        it "should create file instances for the results for the first source to return any values" do
          data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
          file[:source] = sources.keys.sort.map { |key| File.expand_path(key) }
          file.expects(:perform_recursion).with(sources['/a']).returns nil
          file.expects(:perform_recursion).with(sources['/b']).returns []
          file.expects(:perform_recursion).with(sources['/c']).returns [data]
          file.expects(:perform_recursion).with(sources['/d']).never
          file.expects(:newchild).with("foobar").returns @resource
          file.recurse_remote({})
        end
      end

      describe "and :sourceselect is set to :all" do
        before do
          file[:sourceselect] = :all
        end

        it "should return every found file that is not in a previous source" do
          klass = Puppet::FileServing::Metadata
          file[:source] = %w{/a /b /c /d}.map {|f| File.expand_path(f) }
          file.stubs(:newchild).returns @resource

          one = [klass.new("/a", :relative_path => "a")]
          file.expects(:perform_recursion).with(sources['/a']).returns one
          file.expects(:newchild).with("a").returns @resource

          two = [klass.new("/b", :relative_path => "a"), klass.new("/b", :relative_path => "b")]
          file.expects(:perform_recursion).with(sources['/b']).returns two
          file.expects(:newchild).with("b").returns @resource

          three = [klass.new("/c", :relative_path => "a"), klass.new("/c", :relative_path => "c")]
          file.expects(:perform_recursion).with(sources['/c']).returns three
          file.expects(:newchild).with("c").returns @resource

          file.expects(:perform_recursion).with(sources['/d']).returns []

          file.recurse_remote({})
        end
      end
    end
  end

  describe "#perform_recursion" do
    it "should use Metadata to do its recursion" do
      Puppet::FileServing::Metadata.indirection.expects(:search)
      file.perform_recursion(file[:path])
    end

    it "should use the provided path as the key to the search" do
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| key == "/foo" }
      file.perform_recursion("/foo")
    end

    it "should return the results of the metadata search" do
      Puppet::FileServing::Metadata.indirection.expects(:search).returns "foobar"
      file.perform_recursion(file[:path]).should == "foobar"
    end

    it "should pass its recursion value to the search" do
      file[:recurse] = true
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:recurse] == true }
      file.perform_recursion(file[:path])
    end

    it "should pass true if recursion is remote" do
      file[:recurse] = :remote
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:recurse] == true }
      file.perform_recursion(file[:path])
    end

    it "should pass its recursion limit value to the search" do
      file[:recurselimit] = 10
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:recurselimit] == 10 }
      file.perform_recursion(file[:path])
    end

    it "should configure the search to ignore or manage links" do
      file[:links] = :manage
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:links] == :manage }
      file.perform_recursion(file[:path])
    end

    it "should pass its 'ignore' setting to the search if it has one" do
      file[:ignore] = %w{.svn CVS}
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:ignore] == %w{.svn CVS} }
      file.perform_recursion(file[:path])
    end
  end

  describe "#remove_existing" do
    it "should do nothing if the file doesn't exist" do
      file.remove_existing(:file).should == nil
    end

    it "should fail if it can't backup the file" do
      file.stubs(:stat).returns stub('stat')
      file.stubs(:perform_backup).returns false

      expect { file.remove_existing(:file) }.to raise_error(Puppet::Error, /Could not back up; will not replace/)
    end

    it "should not do anything if the file is already the right type and not a link" do
      file.stubs(:stat).returns stub('stat', :ftype => 'file')

      file.remove_existing(:file).should == nil
    end

    it "should not remove directories and should not invalidate the stat unless force is set" do
      # Actually call stat to set @needs_stat to nil
      file.stat
      file.stubs(:stat).returns stub('stat', :ftype => 'directory')

      file.remove_existing(:file)

      file.instance_variable_get(:@stat).should == nil
      @logs.should be_any {|log| log.level == :notice and log.message =~ /Not removing directory; use 'force' to override/}
    end

    it "should remove a directory if force is set" do
      file[:force] = true
      file.stubs(:stat).returns stub('stat', :ftype => 'directory')

      FileUtils.expects(:rmtree).with(file[:path])

      file.remove_existing(:file).should == true
    end

    it "should remove an existing file" do
      file.stubs(:perform_backup).returns true
      FileUtils.touch(path)

      file.remove_existing(:directory).should == true

      File.exists?(file[:path]).should == false
    end

    it "should remove an existing link", :unless => Puppet.features.microsoft_windows? do
      file.stubs(:perform_backup).returns true

      target = tmpfile('link_target')
      FileUtils.touch(target)
      FileUtils.symlink(target, path)
      file[:target] = target

      file.remove_existing(:directory).should == true

      File.exists?(file[:path]).should == false
    end

    it "should fail if the file is not a file, link, or directory" do
      file.stubs(:stat).returns stub('stat', :ftype => 'socket')

      expect { file.remove_existing(:file) }.to raise_error(Puppet::Error, /Could not back up files of type socket/)
    end

    it "should invalidate the existing stat of the file" do
      # Actually call stat to set @needs_stat to nil
      file.stat
      file.stubs(:stat).returns stub('stat', :ftype => 'file')

      File.stubs(:unlink)

      file.remove_existing(:directory).should == true
      file.instance_variable_get(:@stat).should == :needs_stat
    end
  end

  describe "#retrieve" do
    it "should copy the source values if the 'source' parameter is set" do
      file[:source] = File.expand_path('/foo/bar')
      file.parameter(:source).expects(:copy_source_values)
      file.retrieve
    end
  end

  describe "#should_be_file?" do
    it "should have a method for determining if the file should be a normal file" do
      file.must respond_to(:should_be_file?)
    end

    it "should be a file if :ensure is set to :file" do
      file[:ensure] = :file
      file.must be_should_be_file
    end

    it "should be a file if :ensure is set to :present and the file exists as a normal file" do
      file.stubs(:stat).returns(mock('stat', :ftype => "file"))
      file[:ensure] = :present
      file.must be_should_be_file
    end

    it "should not be a file if :ensure is set to something other than :file" do
      file[:ensure] = :directory
      file.must_not be_should_be_file
    end

    it "should not be a file if :ensure is set to :present and the file exists but is not a normal file" do
      file.stubs(:stat).returns(mock('stat', :ftype => "directory"))
      file[:ensure] = :present
      file.must_not be_should_be_file
    end

    it "should be a file if :ensure is not set and :content is" do
      file[:content] = "foo"
      file.must be_should_be_file
    end

    it "should be a file if neither :ensure nor :content is set but the file exists as a normal file" do
      file.stubs(:stat).returns(mock("stat", :ftype => "file"))
      file.must be_should_be_file
    end

    it "should not be a file if neither :ensure nor :content is set but the file exists but not as a normal file" do
      file.stubs(:stat).returns(mock("stat", :ftype => "directory"))
      file.must_not be_should_be_file
    end
  end

  describe "#stat", :unless => Puppet.features.microsoft_windows? do
    before do
      target = tmpfile('link_target')
      FileUtils.touch(target)
      FileUtils.symlink(target, path)

      file[:target] = target
      file[:links] = :manage # so we always use :lstat
    end

    it "should stat the target if it is following links" do
      file[:links] = :follow

      file.stat.ftype.should == 'file'
    end

    it "should stat the link if is it not following links" do
      file[:links] = :manage

      file.stat.ftype.should == 'link'
    end

    it "should return nil if the file does not exist" do
      file[:path] = '/foo/bar/baz/non-existent'

      file.stat.should be_nil
    end

    it "should return nil if the file cannot be stat'ed" do
      dir = tmpfile('link_test_dir')
      child = File.join(dir, 'some_file')
      Dir.mkdir(dir)
      File.chmod(0, dir)

      file[:path] = child

      file.stat.should be_nil

      # chmod it back so we can clean it up
      File.chmod(0777, dir)
    end

    it "should return the stat instance" do
      file.stat.should be_a(File::Stat)
    end

    it "should cache the stat instance" do
      file.stat.should equal(file.stat)
    end
  end

  describe "#write" do
    it "should propagate failures encountered when renaming the temporary file" do
      File.stubs(:open)
      File.expects(:rename).raises ArgumentError

      file[:backup] = 'puppet'

      file.stubs(:validate_checksum?).returns(false)

      property = stub('content_property', :actual_content => "something", :length => "something".length)
      file.stubs(:property).with(:content).returns(property)

      lambda { file.write(:content) }.should raise_error(Puppet::Error)
    end

    it "should delegate writing to the content property" do
      filehandle = stub_everything 'fh'
      File.stubs(:open).yields(filehandle)
      File.stubs(:rename)
      property = stub('content_property', :actual_content => "something", :length => "something".length)
      file[:backup] = 'puppet'

      file.stubs(:validate_checksum?).returns(false)
      file.stubs(:property).with(:content).returns(property)

      property.expects(:write).with(filehandle)

      file.write(:content)
    end

    describe "when validating the checksum" do
      before { file.stubs(:validate_checksum?).returns(true) }

      it "should fail if the checksum parameter and content checksums do not match" do
        checksum = stub('checksum_parameter',  :sum => 'checksum_b', :sum_file => 'checksum_b')
        file.stubs(:parameter).with(:checksum).returns(checksum)

        property = stub('content_property', :actual_content => "something", :length => "something".length, :write => 'checksum_a')
        file.stubs(:property).with(:content).returns(property)

        lambda { file.write :NOTUSED }.should raise_error(Puppet::Error)
      end
    end

    describe "when not validating the checksum" do
      before { file.stubs(:validate_checksum?).returns(false) }

      it "should not fail if the checksum property and content checksums do not match" do
        checksum = stub('checksum_parameter',  :sum => 'checksum_b')
        file.stubs(:parameter).with(:checksum).returns(checksum)

        property = stub('content_property', :actual_content => "something", :length => "something".length, :write => 'checksum_a')
        file.stubs(:property).with(:content).returns(property)

        lambda { file.write :NOTUSED }.should_not raise_error(Puppet::Error)
      end
    end
  end

  describe "#fail_if_checksum_is_wrong" do
    it "should fail if the checksum of the file doesn't match the expected one" do
      expect do
        file.instance_eval do
          parameter(:checksum).stubs(:sum_file).returns('wrong!!')
          fail_if_checksum_is_wrong(self[:path], 'anything!')
        end
      end.to raise_error(Puppet::Error, /File written to disk did not match checksum/)
    end

    it "should not fail if the checksum is correct" do
      file.instance_eval do
        parameter(:checksum).stubs(:sum_file).returns('anything!')
        fail_if_checksum_is_wrong(self[:path], 'anything!').should == nil
      end
    end

    it "should not fail if the checksum is absent" do
      file.instance_eval do
        parameter(:checksum).stubs(:sum_file).returns(nil)
        fail_if_checksum_is_wrong(self[:path], 'anything!').should == nil
      end
    end
  end

  describe "#write_content" do
    it "should delegate writing the file to the content property" do
      io = stub('io')
      file[:content] = "some content here"
      file.property(:content).expects(:write).with(io)

      file.send(:write_content, io)
    end
  end

  describe "#write_temporary_file?" do
    it "should be true if the file has specified content" do
      file[:content] = 'some content'

      file.send(:write_temporary_file?).should be_true
    end

    it "should be true if the file has specified source" do
      file[:source] = File.expand_path('/tmp/foo')

      file.send(:write_temporary_file?).should be_true
    end

    it "should be false if the file has neither content nor source" do
      file.send(:write_temporary_file?).should be_false
    end
  end

  describe "#property_fix" do
    {
      :mode     => 0777,
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
        prop.expects(:retrieve)
        prop.expects(:safe_insync?).returns false
        prop.expects(:sync)

        file.send(:property_fix)
      end
    end
  end

  describe "when autorequiring" do
    describe "target" do
      it "should require file resource when specified with the target property" do
        file = described_class.new(:path => File.expand_path("/foo"), :ensure => :directory)
        link = described_class.new(:path => File.expand_path("/bar"), :ensure => :symlink, :target => File.expand_path("/foo"))
        catalog.add_resource file
        catalog.add_resource link
        reqs = link.autorequire
        reqs.size.must == 1
        reqs[0].source.must == file
        reqs[0].target.must == link
      end

      it "should require file resource when specified with the ensure property" do
        file = described_class.new(:path => File.expand_path("/foo"), :ensure => :directory)
        link = described_class.new(:path => File.expand_path("/bar"), :ensure => File.expand_path("/foo"))
        catalog.add_resource file
        catalog.add_resource link
        reqs = link.autorequire
        reqs.size.must == 1
        reqs[0].source.must == file
        reqs[0].target.must == link
      end

      it "should not require target if target is not managed" do
        link = described_class.new(:path => File.expand_path('/foo'), :ensure => :symlink, :target => '/bar')
        catalog.add_resource link
        link.autorequire.size.should == 0
      end
    end

    describe "directories" do
      it "should autorequire its parent directory" do
        dir = described_class.new(:path => File.dirname(path))
        catalog.add_resource file
        catalog.add_resource dir
        reqs = file.autorequire
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should autorequire its nearest ancestor directory" do
        dir = described_class.new(:path => File.dirname(path))
        grandparent = described_class.new(:path => File.dirname(File.dirname(path)))
        catalog.add_resource file
        catalog.add_resource dir
        catalog.add_resource grandparent
        reqs = file.autorequire
        reqs.length.must == 1
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should not autorequire anything when there is no nearest ancestor directory" do
        catalog.add_resource file
        file.autorequire.should be_empty
      end

      it "should not autorequire its parent dir if its parent dir is itself" do
        file[:path] = File.expand_path('/')
        catalog.add_resource file
        file.autorequire.should be_empty
      end

      describe "on Windows systems", :if => Puppet.features.microsoft_windows? do
        describe "when using UNC filenames" do
          it "should autorequire its parent directory" do
            file[:path] = '//server/foo/bar/baz'
            dir = described_class.new(:path => "//server/foo/bar")
            catalog.add_resource file
            catalog.add_resource dir
            reqs = file.autorequire
            reqs[0].source.must == dir
            reqs[0].target.must == file
          end

          it "should autorequire its nearest ancestor directory" do
            file = described_class.new(:path => "//server/foo/bar/baz/qux")
            dir = described_class.new(:path => "//server/foo/bar/baz")
            grandparent = described_class.new(:path => "//server/foo/bar")
            catalog.add_resource file
            catalog.add_resource dir
            catalog.add_resource grandparent
            reqs = file.autorequire
            reqs.length.must == 1
            reqs[0].source.must == dir
            reqs[0].target.must == file
          end

          it "should not autorequire anything when there is no nearest ancestor directory" do
            file = described_class.new(:path => "//server/foo/bar/baz/qux")
            catalog.add_resource file
            file.autorequire.should be_empty
          end

          it "should not autorequire its parent dir if its parent dir is itself" do
            file = described_class.new(:path => "//server/foo")
            catalog.add_resource file
            puts file.autorequire
            file.autorequire.should be_empty
          end
        end
      end
    end
  end

  describe "when managing links" do
    require 'tempfile'

    if @real_posix
      describe "on POSIX systems" do
        before do
          Dir.mkdir(path)
          @target = File.join(path, "target")
          @link   = File.join(path, "link")

          File.open(@target, "w", 0644) { |f| f.puts "yayness" }
          File.symlink(@target, @link)

          file[:path] = @link
          file[:mode] = 0755

          catalog.add_resource file
        end

        it "should default to managing the link" do
          catalog.apply
          # I convert them to strings so they display correctly if there's an error.
          (File.stat(@target).mode & 007777).to_s(8).should == '644'
        end

        it "should be able to follow links" do
          file[:links] = :follow
          catalog.apply

          (File.stat(@target).mode & 007777).to_s(8).should == '755'
        end
      end
    else # @real_posix
      # should recode tests using expectations instead of using the filesystem
    end

    describe "on Microsoft Windows systems" do
      before do
        Puppet.features.stubs(:posix?).returns(false)
        Puppet.features.stubs(:microsoft_windows?).returns(true)
      end

      it "should refuse to work with links"
    end
  end

  describe "when using source" do
    before do
      file[:source] = File.expand_path('/one')
    end
    Puppet::Type::File::ParameterChecksum.value_collection.values.reject {|v| v == :none}.each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        before do
          file[:checksum] = checksum_type
        end

        it 'should validate' do

          lambda { file.validate }.should_not raise_error
        end
      end
    end

    describe "with checksum 'none'" do
      before do
        file[:checksum] = :none
      end

      it 'should raise an exception when validating' do
        lambda { file.validate }.should raise_error(/You cannot specify source when using checksum 'none'/)
      end
    end
  end

  describe "when using content" do
    before do
      file[:content] = 'file contents'
    end

    (Puppet::Type::File::ParameterChecksum.value_collection.values - SOURCE_ONLY_CHECKSUMS).each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        before do
          file[:checksum] = checksum_type
        end

        it 'should validate' do
          lambda { file.validate }.should_not raise_error
        end
      end
    end

    SOURCE_ONLY_CHECKSUMS.each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        it 'should raise an exception when validating' do
          file[:checksum] = checksum_type

          lambda { file.validate }.should raise_error(/You cannot specify content when using checksum '#{checksum_type}'/)
        end
      end
    end
  end

  describe "when auditing" do
    before :each do
      # to prevent the catalog from trying to write state.yaml
      Puppet::Util::Storage.stubs(:store)
    end

    it "should not fail if creating a new file if group is not set" do
      file = described_class.new(:path => path, :audit => 'all', :content => 'content')
      catalog.add_resource(file)

      report = catalog.apply.report

      report.resource_statuses["File[#{path}]"].should_not be_failed
      File.read(path).should == 'content'
    end

    it "should not log errors if creating a new file with ensure present and no content" do
      file[:audit]  = 'content'
      file[:ensure] = 'present'
      catalog.add_resource(file)

      catalog.apply

      File.should be_exist(path)
      @logs.should_not be_any {|l| l.level != :notice }
    end
  end

  describe "when specifying both source and checksum" do
    it 'should use the specified checksum when source is first' do
      file[:source] = File.expand_path('/foo')
      file[:checksum] = :md5lite

      file[:checksum].should == :md5lite
    end

    it 'should use the specified checksum when source is last' do
      file[:checksum] = :md5lite
      file[:source] = File.expand_path('/foo')

      file[:checksum].should == :md5lite
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
