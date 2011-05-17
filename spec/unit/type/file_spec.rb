#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:file) do
  before do
    Puppet.settings.stubs(:use)
    @real_posix = Puppet.features.posix?
    Puppet.features.stubs("posix?").returns(true)

    @path = Tempfile.new("puppetspec")
    pathname = @path.path
    @path.close!()
    @path = pathname
    @file = Puppet::Type::File.new(:name => @path)

    @catalog = Puppet::Resource::Catalog.new
    @file.catalog = @catalog
  end

  describe "when determining if recursion is enabled" do
    it "should default to recursion being disabled" do
      @file.should_not be_recurse
    end
    [true, "true", 10, "inf", "remote"].each do |value|
      it "should consider #{value} to enable recursion" do
        @file[:recurse] = value
        @file.must be_recurse
      end
    end

    [false, "false", 0].each do |value|
      it "should consider #{value} to disable recursion" do
        @file[:recurse] = value
        @file.should_not be_recurse
      end
    end
  end

  describe "#write" do

    it "should propagate failures encountered when renaming the temporary file" do
      File.stubs(:open)

      File.expects(:rename).raises ArgumentError
      file = Puppet::Type::File.new(:name => "/my/file", :backup => "puppet")

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
      file = Puppet::Type::File.new(:name => "/my/file", :backup => "puppet")
      file.stubs(:validate_checksum?).returns(false)
      file.stubs(:property).with(:content).returns(property)

      property.expects(:write).with(filehandle)

      file.write(:content)
    end

    describe "when validating the checksum" do
      before { @file.stubs(:validate_checksum?).returns(true) }

      it "should fail if the checksum parameter and content checksums do not match" do
        checksum = stub('checksum_parameter',  :sum => 'checksum_b', :sum_file => 'checksum_b')
        @file.stubs(:parameter).with(:checksum).returns(checksum)

        property = stub('content_property', :actual_content => "something", :length => "something".length, :write => 'checksum_a')
        @file.stubs(:property).with(:content).returns(property)

        lambda { @file.write :NOTUSED }.should raise_error(Puppet::Error)
      end
    end

    describe "when not validating the checksum" do
      before { @file.stubs(:validate_checksum?).returns(false) }

      it "should not fail if the checksum property and content checksums do not match" do
        checksum = stub('checksum_parameter',  :sum => 'checksum_b')
        @file.stubs(:parameter).with(:checksum).returns(checksum)

        property = stub('content_property', :actual_content => "something", :length => "something".length, :write => 'checksum_a')
        @file.stubs(:property).with(:content).returns(property)

        lambda { @file.write :NOTUSED }.should_not raise_error(Puppet::Error)
      end

    end
  end

  it "should have a method for determining if the file is present" do
    @file.must respond_to(:exist?)
  end

  it "should be considered existent if it can be stat'ed" do
    @file.expects(:stat).returns mock('stat')
    @file.must be_exist
  end

  it "should be considered nonexistent if it can not be stat'ed" do
    @file.expects(:stat).returns nil
    @file.must_not be_exist
  end

  it "should have a method for determining if the file should be a normal file" do
    @file.must respond_to(:should_be_file?)
  end

  it "should be a file if :ensure is set to :file" do
    @file[:ensure] = :file
    @file.must be_should_be_file
  end

  it "should be a file if :ensure is set to :present and the file exists as a normal file" do
    @file.stubs(:stat).returns(mock('stat', :ftype => "file"))
    @file[:ensure] = :present
    @file.must be_should_be_file
  end

  it "should not be a file if :ensure is set to something other than :file" do
    @file[:ensure] = :directory
    @file.must_not be_should_be_file
  end

  it "should not be a file if :ensure is set to :present and the file exists but is not a normal file" do
    @file.stubs(:stat).returns(mock('stat', :ftype => "directory"))
    @file[:ensure] = :present
    @file.must_not be_should_be_file
  end

  it "should be a file if :ensure is not set and :content is" do
    @file[:content] = "foo"
    @file.must be_should_be_file
  end

  it "should be a file if neither :ensure nor :content is set but the file exists as a normal file" do
    @file.stubs(:stat).returns(mock("stat", :ftype => "file"))
    @file.must be_should_be_file
  end

  it "should not be a file if neither :ensure nor :content is set but the file exists but not as a normal file" do
    @file.stubs(:stat).returns(mock("stat", :ftype => "directory"))
    @file.must_not be_should_be_file
  end

  describe "when using POSIX filenames" do
    describe "on POSIX systems" do
      before do
        Puppet.features.stubs(:posix?).returns(true)
        Puppet.features.stubs(:microsoft_windows?).returns(false)
      end

      it "should autorequire its parent directory" do
        file = Puppet::Type::File.new(:path => "/foo/bar")
        dir = Puppet::Type::File.new(:path => "/foo")
        @catalog.add_resource file
        @catalog.add_resource dir
        reqs = file.autorequire
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should autorequire its nearest ancestor directory" do
        file = Puppet::Type::File.new(:path => "/foo/bar/baz")
        dir = Puppet::Type::File.new(:path => "/foo")
        root = Puppet::Type::File.new(:path => "/")
        @catalog.add_resource file
        @catalog.add_resource dir
        @catalog.add_resource root
        reqs = file.autorequire
        reqs.length.must == 1
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should not autorequire anything when there is no nearest ancestor directory" do
        file = Puppet::Type::File.new(:path => "/foo/bar/baz")
        @catalog.add_resource file
        file.autorequire.should be_empty
      end

      it "should not autorequire its parent dir if its parent dir is itself" do
        file = Puppet::Type::File.new(:path => "/")
        @catalog.add_resource file
        file.autorequire.should be_empty
      end

      it "should remove trailing slashes" do
        file = Puppet::Type::File.new(:path => "/foo/bar/baz/")
        file[:path].should == "/foo/bar/baz"
      end

      it "should remove double slashes" do
        file = Puppet::Type::File.new(:path => "/foo/bar//baz")
        file[:path].should == "/foo/bar/baz"
      end

      it "should remove trailing double slashes" do
        file = Puppet::Type::File.new(:path => "/foo/bar/baz//")
        file[:path].should == "/foo/bar/baz"
      end

      it "should leave a single slash alone" do
        file = Puppet::Type::File.new(:path => "/")
        file[:path].should == "/"
      end

      it "should accept a double-slash at the start of the path" do
        expect {
          file = Puppet::Type::File.new(:path => "//tmp/xxx")
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

    describe "on Microsoft Windows systems" do
      before do
        Puppet.features.stubs(:posix?).returns(false)
        Puppet.features.stubs(:microsoft_windows?).returns(true)
      end

      it "should refuse to work" do
        lambda { Puppet::Type::File.new(:path => "/foo/bar") }.should raise_error(Puppet::Error)
      end
    end
  end

  describe "when using Microsoft Windows filenames", :if => Puppet.features.microsoft_windows? do
    describe "on Microsoft Windows systems" do
      before do
        Puppet.features.stubs(:posix?).returns(false)
        Puppet.features.stubs(:microsoft_windows?).returns(true)
      end

      it "should autorequire its parent directory" do
        file = Puppet::Type::File.new(:path => "X:/foo/bar")
        dir = Puppet::Type::File.new(:path => "X:/foo")
        @catalog.add_resource file
        @catalog.add_resource dir
        reqs = file.autorequire
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should autorequire its nearest ancestor directory" do
        file = Puppet::Type::File.new(:path => "X:/foo/bar/baz")
        dir = Puppet::Type::File.new(:path => "X:/foo")
        root = Puppet::Type::File.new(:path => "X:/")
        @catalog.add_resource file
        @catalog.add_resource dir
        @catalog.add_resource root
        reqs = file.autorequire
        reqs.length.must == 1
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should not autorequire anything when there is no nearest ancestor directory" do
        file = Puppet::Type::File.new(:path => "X:/foo/bar/baz")
        @catalog.add_resource file
        file.autorequire.should be_empty
      end

      it "should not autorequire its parent dir if its parent dir is itself" do
        file = Puppet::Type::File.new(:path => "X:/")
        @catalog.add_resource file
        file.autorequire.should be_empty
      end

      it "should remove trailing slashes" do
        file = Puppet::Type::File.new(:path => "X:/foo/bar/baz/")
        file[:path].should == "X:/foo/bar/baz"
      end

      it "should remove double slashes" do
        file = Puppet::Type::File.new(:path => "X:/foo/bar//baz")
        file[:path].should == "X:/foo/bar/baz"
      end

      it "should remove trailing double slashes" do
        file = Puppet::Type::File.new(:path => "X:/foo/bar/baz//")
        file[:path].should == "X:/foo/bar/baz"
      end

      it "should leave a drive letter with a slash alone", :'fails_on_ruby_1.9.2' => true do
        file = Puppet::Type::File.new(:path => "X:/")
        file[:path].should == "X:/"
      end

      it "should add a slash to a drive letter", :'fails_on_ruby_1.9.2' => true do
        file = Puppet::Type::File.new(:path => "X:")
        file[:path].should == "X:/"
      end
    end

    describe "on POSIX systems" do
      before do
        Puppet.features.stubs(:posix?).returns(true)
        Puppet.features.stubs(:microsoft_windows?).returns(false)
      end

      it "should refuse to work" do
        lambda { Puppet::Type::File.new(:path => "X:/foo/bar") }.should raise_error(Puppet::Error)
      end
    end
  end

  describe "when using UNC filenames" do
    describe "on Microsoft Windows systems", :if => Puppet.features.microsoft_windows?, :'fails_on_ruby_1.9.2' => true do
      before do
        Puppet.features.stubs(:posix?).returns(false)
        Puppet.features.stubs(:microsoft_windows?).returns(true)
      end

      it "should autorequire its parent directory" do
        file = Puppet::Type::File.new(:path => "//server/foo/bar")
        dir = Puppet::Type::File.new(:path => "//server/foo")
        @catalog.add_resource file
        @catalog.add_resource dir
        reqs = file.autorequire
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should autorequire its nearest ancestor directory" do
        file = Puppet::Type::File.new(:path => "//server/foo/bar/baz/qux")
        dir = Puppet::Type::File.new(:path => "//server/foo/bar")
        root = Puppet::Type::File.new(:path => "//server/foo")
        @catalog.add_resource file
        @catalog.add_resource dir
        @catalog.add_resource root
        reqs = file.autorequire
        reqs.length.must == 1
        reqs[0].source.must == dir
        reqs[0].target.must == file
      end

      it "should not autorequire anything when there is no nearest ancestor directory" do
        file = Puppet::Type::File.new(:path => "//server/foo/bar/baz/qux")
        @catalog.add_resource file
        file.autorequire.should be_empty
      end

      it "should not autorequire its parent dir if its parent dir is itself" do
        file = Puppet::Type::File.new(:path => "//server/foo")
        @catalog.add_resource file
        puts file.autorequire
        file.autorequire.should be_empty
      end

      it "should remove trailing slashes" do
        file = Puppet::Type::File.new(:path => "//server/foo/bar/baz/")
        file[:path].should == "//server/foo/bar/baz"
      end

      it "should remove double slashes" do
        file = Puppet::Type::File.new(:path => "//server/foo/bar//baz")
        file[:path].should == "//server/foo/bar/baz"
      end

      it "should remove trailing double slashes" do
        file = Puppet::Type::File.new(:path => "//server/foo/bar/baz//")
        file[:path].should == "//server/foo/bar/baz"
      end

      it "should remove a trailing slash from a sharename" do
        file = Puppet::Type::File.new(:path => "//server/foo/")
        file[:path].should == "//server/foo"
      end

      it "should not modify a sharename" do
        file = Puppet::Type::File.new(:path => "//server/foo")
        file[:path].should == "//server/foo"
      end
    end

    describe "on POSIX systems" do
      before do
        Puppet.features.stubs(:posix?).returns(true)
        Puppet.features.stubs(:microsoft_windows?).returns(false)
      end

      it "should refuse to work" do
        lambda { Puppet::Type::File.new(:path => "X:/foo/bar") }.should raise_error(Puppet::Error)
      end
    end
  end

  describe "when initializing" do
    it "should set a desired 'ensure' value if none is set and 'content' is set" do
      file = Puppet::Type::File.new(:name => "/my/file", :content => "/foo/bar")
      file[:ensure].should == :file
    end

    it "should set a desired 'ensure' value if none is set and 'target' is set" do
      file = Puppet::Type::File.new(:name => "/my/file", :target => "/foo/bar")
      file[:ensure].should == :symlink
    end
  end

  describe "when validating attributes" do
    %w{path checksum backup recurse recurselimit source replace force ignore links purge sourceselect}.each do |attr|
      it "should have a '#{attr}' parameter" do
        Puppet::Type.type(:file).attrtype(attr.intern).should == :param
      end
    end

    %w{content target ensure owner group mode type}.each do |attr|
      it "should have a '#{attr}' property" do
        Puppet::Type.type(:file).attrtype(attr.intern).should == :property
      end
    end

    it "should have its 'path' attribute set as its namevar" do
      Puppet::Type.type(:file).key_attributes.should == [:path]
    end
  end

  describe "when managing links" do
    require 'tempfile'

    if @real_posix
      describe "on POSIX systems" do
        before do
          @basedir = tempfile
          Dir.mkdir(@basedir)
          @file = File.join(@basedir, "file")
          @link = File.join(@basedir, "link")

          File.open(@file, "w", 0644) { |f| f.puts "yayness"; f.flush }
          File.symlink(@file, @link)

          @resource = Puppet::Type.type(:file).new(:path => @link, :mode => "755")
          @catalog.add_resource @resource
        end

        after do
          remove_tmp_files
        end

        it "should default to managing the link" do
          @catalog.apply
          # I convert them to strings so they display correctly if there's an error.
          ("%o" % (File.stat(@file).mode & 007777)).should == "%o" % 0644
        end

        it "should be able to follow links" do
          @resource[:links] = :follow
          @catalog.apply

          ("%o" % (File.stat(@file).mode & 007777)).should == "%o" % 0755
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

  it "should be able to retrieve a stat instance for the file it is managing" do
    Puppet::Type.type(:file).new(:path => "/foo/bar", :source => "/bar/foo").should respond_to(:stat)
  end

  describe "when stat'ing its file" do
    before do
      @resource = Puppet::Type.type(:file).new(:path => "/foo/bar")
      @resource[:links] = :manage # so we always use :lstat
    end

    it "should use :stat if it is following links" do
      @resource[:links] = :follow
      File.expects(:stat)

      @resource.stat
    end

    it "should use :lstat if is it not following links" do
      @resource[:links] = :manage
      File.expects(:lstat)

      @resource.stat
    end

    it "should stat the path of the file" do
      File.expects(:lstat).with("/foo/bar")

      @resource.stat
    end

    # This only happens in testing.
    it "should return nil if the stat does not exist" do
      File.expects(:lstat).returns nil

      @resource.stat.should be_nil
    end

    it "should return nil if the file does not exist" do
      File.expects(:lstat).raises(Errno::ENOENT)

      @resource.stat.should be_nil
    end

    it "should return nil if the file cannot be stat'ed" do
      File.expects(:lstat).raises(Errno::EACCES)

      @resource.stat.should be_nil
    end

    it "should return the stat instance" do
      File.expects(:lstat).returns "mystat"

      @resource.stat.should == "mystat"
    end

    it "should cache the stat instance if it has a catalog and is applying" do
      stat = mock 'stat'
      File.expects(:lstat).returns stat

      catalog = Puppet::Resource::Catalog.new
      @resource.catalog = catalog

      catalog.stubs(:applying?).returns true

      @resource.stat.should equal(@resource.stat)
    end
  end

  describe "when flushing" do
    it "should flush all properties that respond to :flush" do
      @resource = Puppet::Type.type(:file).new(:path => "/foo/bar", :source => "/bar/foo")
      @resource.parameter(:source).expects(:flush)
      @resource.flush
    end

    it "should reset its stat reference" do
      @resource = Puppet::Type.type(:file).new(:path => "/foo/bar")
      File.expects(:lstat).times(2).returns("stat1").then.returns("stat2")
      @resource.stat.should == "stat1"
      @resource.flush
      @resource.stat.should == "stat2"
    end
  end

  it "should have a method for performing recursion" do
    @file.must respond_to(:perform_recursion)
  end

  describe "when executing a recursive search" do
    it "should use Metadata to do its recursion" do
      Puppet::FileServing::Metadata.indirection.expects(:search)
      @file.perform_recursion(@file[:path])
    end

    it "should use the provided path as the key to the search" do
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| key == "/foo" }
      @file.perform_recursion("/foo")
    end

    it "should return the results of the metadata search" do
      Puppet::FileServing::Metadata.indirection.expects(:search).returns "foobar"
      @file.perform_recursion(@file[:path]).should == "foobar"
    end

    it "should pass its recursion value to the search" do
      @file[:recurse] = true
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:recurse] == true }
      @file.perform_recursion(@file[:path])
    end

    it "should pass true if recursion is remote" do
      @file[:recurse] = :remote
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:recurse] == true }
      @file.perform_recursion(@file[:path])
    end

    it "should pass its recursion limit value to the search" do
      @file[:recurselimit] = 10
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:recurselimit] == 10 }
      @file.perform_recursion(@file[:path])
    end

    it "should configure the search to ignore or manage links" do
      @file[:links] = :manage
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:links] == :manage }
      @file.perform_recursion(@file[:path])
    end

    it "should pass its 'ignore' setting to the search if it has one" do
      @file[:ignore] = %w{.svn CVS}
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |key, options| options[:ignore] == %w{.svn CVS} }
      @file.perform_recursion(@file[:path])
    end
  end

  it "should have a method for performing local recursion" do
    @file.must respond_to(:recurse_local)
  end

  describe "when doing local recursion" do
    before do
      @metadata = stub 'metadata', :relative_path => "my/file"
    end

    it "should pass its path to the :perform_recursion method" do
      @file.expects(:perform_recursion).with(@file[:path]).returns [@metadata]
      @file.stubs(:newchild)
      @file.recurse_local
    end

    it "should return an empty hash if the recursion returns nothing" do
      @file.expects(:perform_recursion).returns nil
      @file.recurse_local.should == {}
    end

    it "should create a new child resource with each generated metadata instance's relative path" do
      @file.expects(:perform_recursion).returns [@metadata]
      @file.expects(:newchild).with(@metadata.relative_path).returns "fiebar"
      @file.recurse_local
    end

    it "should not create a new child resource for the '.' directory" do
      @metadata.stubs(:relative_path).returns "."

      @file.expects(:perform_recursion).returns [@metadata]
      @file.expects(:newchild).never
      @file.recurse_local
    end

    it "should return a hash of the created resources with the relative paths as the hash keys" do
      @file.expects(:perform_recursion).returns [@metadata]
      @file.expects(:newchild).with("my/file").returns "fiebar"
      @file.recurse_local.should == {"my/file" => "fiebar"}
    end

    it "should set checksum_type to none if this file checksum is none" do
      @file[:checksum] = :none
      Puppet::FileServing::Metadata.indirection.expects(:search).with { |path,params| params[:checksum_type] == :none }.returns [@metadata]
      @file.expects(:newchild).with("my/file").returns "fiebar"
      @file.recurse_local
    end
  end

  it "should have a method for performing link recursion" do
    @file.must respond_to(:recurse_link)
  end

  describe "when doing link recursion" do
    before do
      @first = stub 'first', :relative_path => "first", :full_path => "/my/first", :ftype => "directory"
      @second = stub 'second', :relative_path => "second", :full_path => "/my/second", :ftype => "file"

      @resource = stub 'file', :[]= => nil
    end

    it "should pass its target to the :perform_recursion method" do
      @file[:target] = "mylinks"
      @file.expects(:perform_recursion).with("mylinks").returns [@first]
      @file.stubs(:newchild).returns @resource
      @file.recurse_link({})
    end

    it "should ignore the recursively-found '.' file and configure the top-level file to create a directory" do
      @first.stubs(:relative_path).returns "."
      @file[:target] = "mylinks"
      @file.expects(:perform_recursion).with("mylinks").returns [@first]
      @file.stubs(:newchild).never
      @file.expects(:[]=).with(:ensure, :directory)
      @file.recurse_link({})
    end

    it "should create a new child resource for each generated metadata instance's relative path that doesn't already exist in the children hash" do
      @file.expects(:perform_recursion).returns [@first, @second]
      @file.expects(:newchild).with(@first.relative_path).returns @resource
      @file.recurse_link("second" => @resource)
    end

    it "should not create a new child resource for paths that already exist in the children hash" do
      @file.expects(:perform_recursion).returns [@first]
      @file.expects(:newchild).never
      @file.recurse_link("first" => @resource)
    end

    it "should set the target to the full path of discovered file and set :ensure to :link if the file is not a directory" do
      file = stub 'file'
      file.expects(:[]=).with(:target, "/my/second")
      file.expects(:[]=).with(:ensure, :link)

      @file.stubs(:perform_recursion).returns [@first, @second]
      @file.recurse_link("first" => @resource, "second" => file)
    end

    it "should :ensure to :directory if the file is a directory" do
      file = stub 'file'
      file.expects(:[]=).with(:ensure, :directory)

      @file.stubs(:perform_recursion).returns [@first, @second]
      @file.recurse_link("first" => file, "second" => @resource)
    end

    it "should return a hash with both created and existing resources with the relative paths as the hash keys" do
      file = stub 'file', :[]= => nil

      @file.expects(:perform_recursion).returns [@first, @second]
      @file.stubs(:newchild).returns file
      @file.recurse_link("second" => @resource).should == {"second" => @resource, "first" => file}
    end
  end

  it "should have a method for performing remote recursion" do
    @file.must respond_to(:recurse_remote)
  end

  describe "when doing remote recursion" do
    before do
      @file[:source] = "puppet://foo/bar"

      @first = Puppet::FileServing::Metadata.new("/my", :relative_path => "first")
      @second = Puppet::FileServing::Metadata.new("/my", :relative_path => "second")
      @first.stubs(:ftype).returns "directory"
      @second.stubs(:ftype).returns "directory"

      @parameter = stub 'property', :metadata= => nil
      @resource = stub 'file', :[]= => nil, :parameter => @parameter
    end

    it "should pass its source to the :perform_recursion method" do
      data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
      @file.expects(:perform_recursion).with("puppet://foo/bar").returns [data]
      @file.stubs(:newchild).returns @resource
      @file.recurse_remote({})
    end

    it "should not recurse when the remote file is not a directory" do
      data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => ".")
      data.stubs(:ftype).returns "file"
      @file.expects(:perform_recursion).with("puppet://foo/bar").returns [data]
      @file.expects(:newchild).never
      @file.recurse_remote({})
    end

    it "should set the source of each returned file to the searched-for URI plus the found relative path" do
      @first.expects(:source=).with File.join("puppet://foo/bar", @first.relative_path)
      @file.expects(:perform_recursion).returns [@first]
      @file.stubs(:newchild).returns @resource
      @file.recurse_remote({})
    end

    it "should create a new resource for any relative file paths that do not already have a resource" do
      @file.stubs(:perform_recursion).returns [@first]
      @file.expects(:newchild).with("first").returns @resource
      @file.recurse_remote({}).should == {"first" => @resource}
    end

    it "should not create a new resource for any relative file paths that do already have a resource" do
      @file.stubs(:perform_recursion).returns [@first]
      @file.expects(:newchild).never
      @file.recurse_remote("first" => @resource)
    end

    it "should set the source of each resource to the source of the metadata" do
      @file.stubs(:perform_recursion).returns [@first]
      @resource.stubs(:[]=)
      @resource.expects(:[]=).with(:source, File.join("puppet://foo/bar", @first.relative_path))
      @file.recurse_remote("first" => @resource)
    end

    # LAK:FIXME This is a bug, but I can't think of a fix for it.  Fortunately it's already
    # filed, and when it's fixed, we'll just fix the whole flow.
    it "should set the checksum type to :md5 if the remote file is a file" do
      @first.stubs(:ftype).returns "file"
      @file.stubs(:perform_recursion).returns [@first]
      @resource.stubs(:[]=)
      @resource.expects(:[]=).with(:checksum, :md5)
      @file.recurse_remote("first" => @resource)
    end

    it "should store the metadata in the source property for each resource so the source does not have to requery the metadata" do
      @file.stubs(:perform_recursion).returns [@first]
      @resource.expects(:parameter).with(:source).returns @parameter

      @parameter.expects(:metadata=).with(@first)

      @file.recurse_remote("first" => @resource)
    end

    it "should not create a new resource for the '.' file" do
      @first.stubs(:relative_path).returns "."
      @file.stubs(:perform_recursion).returns [@first]

      @file.expects(:newchild).never

      @file.recurse_remote({})
    end

    it "should store the metadata in the main file's source property if the relative path is '.'" do
      @first.stubs(:relative_path).returns "."
      @file.stubs(:perform_recursion).returns [@first]

      @file.parameter(:source).expects(:metadata=).with @first

      @file.recurse_remote("first" => @resource)
    end

    describe "and multiple sources are provided" do
      describe "and :sourceselect is set to :first" do
        it "should create file instances for the results for the first source to return any values" do
          data = Puppet::FileServing::Metadata.new("/whatever", :relative_path => "foobar")
          @file[:source] = %w{/one /two /three /four}
          @file.expects(:perform_recursion).with("/one").returns nil
          @file.expects(:perform_recursion).with("/two").returns []
          @file.expects(:perform_recursion).with("/three").returns [data]
          @file.expects(:perform_recursion).with("/four").never
          @file.expects(:newchild).with("foobar").returns @resource
          @file.recurse_remote({})
        end
      end

      describe "and :sourceselect is set to :all" do
        before do
          @file[:sourceselect] = :all
        end

        it "should return every found file that is not in a previous source" do
          klass = Puppet::FileServing::Metadata
          @file[:source] = %w{/one /two /three /four}
          @file.stubs(:newchild).returns @resource

          one = [klass.new("/one", :relative_path => "a")]
          @file.expects(:perform_recursion).with("/one").returns one
          @file.expects(:newchild).with("a").returns @resource

          two = [klass.new("/two", :relative_path => "a"), klass.new("/two", :relative_path => "b")]
          @file.expects(:perform_recursion).with("/two").returns two
          @file.expects(:newchild).with("b").returns @resource

          three = [klass.new("/three", :relative_path => "a"), klass.new("/three", :relative_path => "c")]
          @file.expects(:perform_recursion).with("/three").returns three
          @file.expects(:newchild).with("c").returns @resource

          @file.expects(:perform_recursion).with("/four").returns []

          @file.recurse_remote({})
        end
      end
    end
  end

  describe "when specifying both source, and content properties" do
    before do
      @file[:source]  = '/one'
      @file[:content] = 'file contents'
    end

    it "should raise an exception" do
      lambda {@file.validate }.should raise_error(/You cannot specify more than one of/)
    end
  end

  describe "when using source" do
    before do
      @file[:source]   = '/one'
    end
    Puppet::Type::File::ParameterChecksum.value_collection.values.reject {|v| v == :none}.each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        before do
          @file[:checksum] = checksum_type
        end

        it 'should validate' do

          lambda { @file.validate }.should_not raise_error
        end
      end
    end

    describe "with checksum 'none'" do
      before do
        @file[:checksum] = :none
      end

      it 'should raise an exception when validating' do
        lambda { @file.validate }.should raise_error(/You cannot specify source when using checksum 'none'/)
      end
    end
  end

  describe "when using content" do
    before do
      @file[:content] = 'file contents'
    end

    (Puppet::Type::File::ParameterChecksum.value_collection.values - SOURCE_ONLY_CHECKSUMS).each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        before do
          @file[:checksum] = checksum_type
        end

        it 'should validate' do
          lambda { @file.validate }.should_not raise_error
        end
      end
    end

    SOURCE_ONLY_CHECKSUMS.each do |checksum_type|
      describe "with checksum '#{checksum_type}'" do
        it 'should raise an exception when validating' do
          @file[:checksum] = checksum_type

          lambda { @file.validate }.should raise_error(/You cannot specify content when using checksum '#{checksum_type}'/)
        end
      end
    end
  end

  describe "when returning resources with :eval_generate" do
    before do
      @graph = stub 'graph', :add_edge => nil
      @catalog.stubs(:relationship_graph).returns @graph

      @file.catalog = @catalog
      @file[:recurse] = true
    end

    it "should recurse if recursion is enabled" do
      resource = stub('resource', :[] => "resource")
      @file.expects(:recurse?).returns true
      @file.expects(:recurse).returns [resource]
      @file.eval_generate.should == [resource]
    end

    it "should not recurse if recursion is disabled" do
      @file.expects(:recurse?).returns false
      @file.expects(:recurse).never
      @file.eval_generate.should == []
    end

    it "should return each resource found through recursion" do
      foo = stub 'foo', :[] => "/foo"
      bar = stub 'bar', :[] => "/bar"
      bar2 = stub 'bar2', :[] => "/bar"

      @file.expects(:recurse).returns [foo, bar]

      @file.eval_generate.should == [foo, bar]
    end
  end

  describe "when recursing" do
    before do
      @file[:recurse] = true
      @metadata = Puppet::FileServing::Metadata
    end

    describe "and a source is set" do
      before { @file[:source] = "/my/source" }

      it "should pass the already-discovered resources to recurse_remote" do
        @file.stubs(:recurse_local).returns(:foo => "bar")
        @file.expects(:recurse_remote).with(:foo => "bar").returns []
        @file.recurse
      end
    end

    describe "and a target is set" do
      before { @file[:target] = "/link/target" }

      it "should use recurse_link" do
        @file.stubs(:recurse_local).returns(:foo => "bar")
        @file.expects(:recurse_link).with(:foo => "bar").returns []
        @file.recurse
      end
    end

    it "should use recurse_local if recurse is not remote" do
      @file.expects(:recurse_local).returns({})
      @file.recurse
    end

    it "should not use recurse_local if recurse remote" do
      @file[:recurse] = :remote
      @file.expects(:recurse_local).never
      @file.recurse
    end

    it "should return the generated resources as an array sorted by file path" do
      one = stub 'one', :[] => "/one"
      two = stub 'two', :[] => "/one/two"
      three = stub 'three', :[] => "/three"
      @file.expects(:recurse_local).returns(:one => one, :two => two, :three => three)
      @file.recurse.should == [one, two, three]
    end

    describe "and purging is enabled" do
      before do
        @file[:purge] = true
      end

      it "should configure each file to be removed" do
        local = stub 'local'
        local.stubs(:[]).with(:source).returns nil # Thus, a local file
        local.stubs(:[]).with(:path).returns "foo"
        @file.expects(:recurse_local).returns("local" => local)
        local.expects(:[]=).with(:ensure, :absent)

        @file.recurse
      end

      it "should not remove files that exist in the remote repository" do
        @file["source"] = "/my/file"
        @file.expects(:recurse_local).returns({})

        remote = stub 'remote'
        remote.stubs(:[]).with(:source).returns "/whatever" # Thus, a remote file
        remote.stubs(:[]).with(:path).returns "foo"

        @file.expects(:recurse_remote).with { |hash| hash["remote"] = remote }
        remote.expects(:[]=).with(:ensure, :absent).never

        @file.recurse
      end
    end

    describe "and making a new child resource" do
      it "should not copy the parent resource's parent" do
        Puppet::Type.type(:file).expects(:new).with { |options| ! options.include?(:parent) }
        @file.newchild("my/path")
      end

      {:recurse => true, :target => "/foo/bar", :ensure => :present, :alias => "yay", :source => "/foo/bar"}.each do |param, value|
        it "should not pass on #{param} to the sub resource" do
          @file = Puppet::Type::File.new(:name => @path, param => value, :catalog => @catalog)

          @file.class.expects(:new).with { |params| params[param].nil? }

          @file.newchild("sub/file")
        end
      end

      it "should copy all of the parent resource's 'should' values that were set at initialization" do
        file = @file.class.new(:path => "/foo/bar", :owner => "root", :group => "wheel")
        @catalog.add_resource(file)
        file.class.expects(:new).with { |options| options[:owner] == "root" and options[:group] == "wheel" }
        file.newchild("my/path")
      end

      it "should not copy default values to the new child" do
        @file.class.expects(:new).with { |params| params[:backup].nil? }
        @file.newchild("my/path")
      end

      it "should not copy values to the child which were set by the source" do
        @file[:source] = "/foo/bar"
        metadata = stub 'metadata', :owner => "root", :group => "root", :mode => 0755, :ftype => "file", :checksum => "{md5}whatever"
        @file.parameter(:source).stubs(:metadata).returns metadata

        @file.parameter(:source).copy_source_values

        @file.class.expects(:new).with { |params| params[:group].nil? }
        @file.newchild("my/path")
      end
    end
  end

  describe "when setting the backup" do
    it "should default to 'puppet'" do
      Puppet::Type::File.new(:name => "/my/file")[:backup].should == "puppet"
    end

    it "should allow setting backup to 'false'" do
      (!Puppet::Type::File.new(:name => "/my/file", :backup => false)[:backup]).should be_true
    end

    it "should set the backup to '.puppet-bak' if it is set to true" do
      Puppet::Type::File.new(:name => "/my/file", :backup => true)[:backup].should == ".puppet-bak"
    end

    it "should support any other backup extension" do
      Puppet::Type::File.new(:name => "/my/file", :backup => ".bak")[:backup].should == ".bak"
    end

    it "should set the filebucket when backup is set to a string matching the name of a filebucket in the catalog" do
      catalog = Puppet::Resource::Catalog.new
      bucket_resource = Puppet::Type.type(:filebucket).new :name => "foo", :path => "/my/file/bucket"
      catalog.add_resource bucket_resource

      file = Puppet::Type::File.new(:name => "/my/file")
      catalog.add_resource file

      file[:backup] = "foo"
      file.bucket.should == bucket_resource.bucket
    end

    it "should find filebuckets added to the catalog after the file resource was created" do
      catalog = Puppet::Resource::Catalog.new

      file = Puppet::Type::File.new(:name => "/my/file", :backup => "foo")
      catalog.add_resource file

      bucket_resource = Puppet::Type.type(:filebucket).new :name => "foo", :path => "/my/file/bucket"
      catalog.add_resource bucket_resource

      file.bucket.should == bucket_resource.bucket
    end

    it "should have a nil filebucket if backup is false" do
      catalog = Puppet::Resource::Catalog.new
      bucket_resource = Puppet::Type.type(:filebucket).new :name => "foo", :path => "/my/file/bucket"
      catalog.add_resource bucket_resource

      file = Puppet::Type::File.new(:name => "/my/file", :backup => false)
      catalog.add_resource file

      file.bucket.should be_nil
    end

    it "should have a nil filebucket if backup is set to a string starting with '.'" do
      catalog = Puppet::Resource::Catalog.new
      bucket_resource = Puppet::Type.type(:filebucket).new :name => "foo", :path => "/my/file/bucket"
      catalog.add_resource bucket_resource

      file = Puppet::Type::File.new(:name => "/my/file", :backup => ".foo")
      catalog.add_resource file

      file.bucket.should be_nil
    end

    it "should fail if there's no catalog and backup is not false" do
      file = Puppet::Type::File.new(:name => "/my/file", :backup => "foo")

      lambda { file.bucket }.should raise_error(Puppet::Error)
    end

    it "should fail if a non-existent catalog is specified" do
      file = Puppet::Type::File.new(:name => "/my/file", :backup => "foo")
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource file

      lambda { file.bucket }.should raise_error(Puppet::Error)
    end

    it "should be able to use the default filebucket without a catalog" do
      file = Puppet::Type::File.new(:name => "/my/file", :backup => "puppet")
      file.bucket.should be_instance_of(Puppet::FileBucket::Dipper)
    end

    it "should look up the filebucket during finish()" do
      file = Puppet::Type::File.new(:name => "/my/file", :backup => ".foo")
      file.expects(:bucket)
      file.finish
    end
  end

  describe "when retrieving the current file state" do
    it "should copy the source values if the 'source' parameter is set" do
      file = Puppet::Type::File.new(:name => "/my/file", :source => "/foo/bar")
      file.parameter(:source).expects(:copy_source_values)
      file.retrieve
    end
  end

  describe ".title_patterns" do
    before do
      @type_class = Puppet::Type.type(:file)
    end

    it "should have a regexp that captures the entire string, except for a terminating slash" do
      patterns = @type_class.title_patterns
      string = "abc/\n\tdef/"
      patterns[0][0] =~ string
      $1.should == "abc/\n\tdef"
    end
  end

  describe "when auditing" do
    it "should not fail if creating a new file if group is not set" do
      File.exists?(@path).should == false
      file = Puppet::Type::File.new(:name => @path, :audit => "all", :content => "content")
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource(file)

      Puppet::Util::Storage.stubs(:store) # to prevent the catalog from trying to write state.yaml
      transaction = catalog.apply

      transaction.report.resource_statuses["File[#{@path}]"].failed.should == false
      File.exists?(@path).should == true
    end

    it "should not log errors if creating a new file with ensure present and no content" do
      File.exists?(@path).should == false
      file = Puppet::Type::File.new(:name => @path, :audit => "content", :ensure => "present")
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource(file)

      Puppet::Util::Storage.stubs(:store) # to prevent the catalog from trying to write state.yaml

      catalog.apply
      @logs.reject {|l| l.level == :notice }.should be_empty
    end
  end

  describe "when specifying both source and checksum" do
    it 'should use the specified checksum when source is first' do
      @file[:source] = '/foo'
      @file[:checksum] = :md5lite

      @file[:checksum].should be :md5lite
    end
    it 'should use the specified checksum when source is last' do
      @file[:checksum] = :md5lite
      @file[:source] = '/foo'

      @file[:checksum].should be :md5lite
    end
  end
end
