#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/autoload'

describe Puppet::Util::Autoload do
  include PuppetSpec::Files
  before do
    @autoload = Puppet::Util::Autoload.new("foo", "tmp")

    @autoload.stubs(:eachdir).yields make_absolute("/my/dir")
    @loaded = {}
    @autoload.class.stubs(:loaded).returns(@loaded)
  end

  describe "when building the search path" do
    before :each do
      ## modulepath/libdir can't be used until after app settings are initialized, so we need to simulate that:
      Puppet.settings.expects(:app_defaults_initialized?).returns(true).at_least_once

      @dira = File.expand_path('/a')
      @dirb = File.expand_path('/b')
      @dirc = File.expand_path('/c')
    end

    it "should collect all of the lib directories that exist in the current environment's module path" do
      environment = Puppet::Node::Environment.create(:foo, [@dira, @dirb, @dirc])
      Dir.expects(:entries).with(@dira).returns %w{. .. one two}
      Dir.expects(:entries).with(@dirb).returns %w{. .. one two}

      Puppet::FileSystem.expects(:directory?).with(@dira).returns true
      Puppet::FileSystem.expects(:directory?).with(@dirb).returns true
      Puppet::FileSystem.expects(:directory?).with(@dirc).returns false

      FileTest.expects(:directory?).with(regexp_matches(%r{two/lib})).times(2).returns true
      FileTest.expects(:directory?).with(regexp_matches(%r{one/lib})).times(2).returns false

      @autoload.class.module_directories(environment).should == ["#{@dira}/two/lib", "#{@dirb}/two/lib"]
    end

    it "should include the module directories, the Puppet libdir, and all of the Ruby load directories" do
      Puppet[:libdir] = %w{/libdir1 /lib/dir/two /third/lib/dir}.join(File::PATH_SEPARATOR)
      @autoload.class.expects(:gem_directories).returns %w{/one /two}
      @autoload.class.expects(:module_directories).returns %w{/three /four}
      @autoload.class.search_directories(nil).should == %w{/one /two /three /four} + Puppet[:libdir].split(File::PATH_SEPARATOR) + $LOAD_PATH
    end
  end

  describe "when loading a file" do
    before do
      @autoload.class.stubs(:search_directories).returns [make_absolute("/a")]
      FileTest.stubs(:directory?).returns true
      @time_a = Time.utc(2010, 'jan', 1, 6, 30)
      File.stubs(:mtime).returns @time_a
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die with Puppet::Error if a #{error.to_s} exception is thrown" do
        Puppet::FileSystem.stubs(:exist?).returns true

        Kernel.expects(:load).raises error

        lambda { @autoload.load("foo") }.should raise_error(Puppet::Error)
      end
    end

    it "should not raise an error if the file is missing" do
      @autoload.load("foo").should == false
    end

    it "should register loaded files with the autoloader" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Kernel.stubs(:load)
      @autoload.load("myfile")

      @autoload.class.loaded?("tmp/myfile.rb").should be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should be seen by loaded? on the instance using the short name" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Kernel.stubs(:load)
      @autoload.load("myfile")

      @autoload.loaded?("myfile.rb").should be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should register loaded files with the main loaded file list so they are not reloaded by ruby" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Kernel.stubs(:load)

      @autoload.load("myfile")

      $LOADED_FEATURES.should be_include("tmp/myfile.rb")

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should load the first file in the searchpath" do
      @autoload.stubs(:search_directories).returns [make_absolute("/a"), make_absolute("/b")]
      FileTest.stubs(:directory?).returns true
      Puppet::FileSystem.stubs(:exist?).returns true
      Kernel.expects(:load).with(make_absolute("/a/tmp/myfile.rb"), optionally(anything))

      @autoload.load("myfile")

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    it "should treat equivalent paths to a loaded file as loaded" do
      Puppet::FileSystem.stubs(:exist?).returns true
      Kernel.stubs(:load)
      @autoload.load("myfile")

      @autoload.class.loaded?("tmp/myfile").should be
      @autoload.class.loaded?("tmp/./myfile.rb").should be
      @autoload.class.loaded?("./tmp/myfile.rb").should be
      @autoload.class.loaded?("tmp/../tmp/myfile.rb").should be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end
  end

  describe "when loading all files" do
    before do
      @autoload.class.stubs(:search_directories).returns [make_absolute("/a")]
      FileTest.stubs(:directory?).returns true
      Dir.stubs(:glob).returns [make_absolute("/a/foo/file.rb")]
      Puppet::FileSystem.stubs(:exist?).returns true
      @time_a = Time.utc(2010, 'jan', 1, 6, 30)
      File.stubs(:mtime).returns @time_a

      @autoload.class.stubs(:loaded?).returns(false)
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die an if a #{error.to_s} exception is thrown" do
        Kernel.expects(:load).raises error

        lambda { @autoload.loadall }.should raise_error(Puppet::Error)
      end
    end

    it "should require the full path to the file" do
      Kernel.expects(:load).with(make_absolute("/a/foo/file.rb"), optionally(anything))

      @autoload.loadall
    end
  end

  describe "when reloading files" do
    before :each do
      @file_a = make_absolute("/a/file.rb")
      @file_b = make_absolute("/b/file.rb")
      @first_time = Time.utc(2010, 'jan', 1, 6, 30)
      @second_time = @first_time + 60
    end

    after :each do
      $LOADED_FEATURES.delete("a/file.rb")
      $LOADED_FEATURES.delete("b/file.rb")
    end

    it "#changed? should return true for a file that was not loaded" do
      @autoload.class.changed?(@file_a).should be
    end

    it "changes should be seen by changed? on the instance using the short name" do
      File.stubs(:mtime).returns(@first_time)
      Puppet::FileSystem.stubs(:exist?).returns true
      Kernel.stubs(:load)
      @autoload.load("myfile")
      @autoload.loaded?("myfile").should be
      @autoload.changed?("myfile").should_not be

      File.stubs(:mtime).returns(@second_time)
      @autoload.changed?("myfile").should be

      $LOADED_FEATURES.delete("tmp/myfile.rb")
    end

    describe "in one directory" do
      before :each do
        @autoload.class.stubs(:search_directories).returns [make_absolute("/a")]
        File.expects(:mtime).with(@file_a).returns(@first_time)
        @autoload.class.mark_loaded("file", @file_a)
      end

      it "should reload if mtime changes" do
        File.stubs(:mtime).with(@file_a).returns(@first_time + 60)
        Puppet::FileSystem.stubs(:exist?).with(@file_a).returns true
        Kernel.expects(:load).with(@file_a, optionally(anything))
        @autoload.class.reload_changed
      end

      it "should do nothing if the file is deleted" do
        File.stubs(:mtime).with(@file_a).raises(Errno::ENOENT)
        Puppet::FileSystem.stubs(:exist?).with(@file_a).returns false
        Kernel.expects(:load).never
        @autoload.class.reload_changed
      end
    end

    describe "in two directories" do
      before :each do
        @autoload.class.stubs(:search_directories).returns [make_absolute("/a"), make_absolute("/b")]
      end

      it "should load b/file when a/file is deleted" do
        File.expects(:mtime).with(@file_a).returns(@first_time)
        @autoload.class.mark_loaded("file", @file_a)
        File.stubs(:mtime).with(@file_a).raises(Errno::ENOENT)
        Puppet::FileSystem.stubs(:exist?).with(@file_a).returns false
        Puppet::FileSystem.stubs(:exist?).with(@file_b).returns true
        File.stubs(:mtime).with(@file_b).returns @first_time
        Kernel.expects(:load).with(@file_b, optionally(anything))
        @autoload.class.reload_changed
        @autoload.class.send(:loaded)["file"].should == [@file_b, @first_time]
      end

      it "should load a/file when b/file is loaded and a/file is created" do
        File.stubs(:mtime).with(@file_b).returns @first_time
        Puppet::FileSystem.stubs(:exist?).with(@file_b).returns true
        @autoload.class.mark_loaded("file", @file_b)

        File.stubs(:mtime).with(@file_a).returns @first_time
        Puppet::FileSystem.stubs(:exist?).with(@file_a).returns true
        Kernel.expects(:load).with(@file_a, optionally(anything))
        @autoload.class.reload_changed
        @autoload.class.send(:loaded)["file"].should == [@file_a, @first_time]
      end
    end
  end

  describe "#cleanpath" do
    it "should leave relative paths relative" do
      path = "hello/there"
      Puppet::Util::Autoload.cleanpath(path).should == path
    end

    describe "on Windows", :if => Puppet.features.microsoft_windows? do
      it "should convert c:\ to c:/" do
        Puppet::Util::Autoload.cleanpath('c:\\').should == 'c:/'
      end
    end
  end

  describe "#expand" do
    it "should expand relative to the autoloader's prefix" do
      @autoload.expand('bar').should == 'tmp/bar'
    end
  end
end
