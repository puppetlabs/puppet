#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/autoload'

describe Puppet::Util::Autoload do
  include PuppetSpec::Files

  before do
    @autoload = Puppet::Util::Autoload.new("foo", "tmp")

    @autoload.stubs(:eachdir).yields "/my/dir"
  end

  describe "when building the search path" do
    before :each do
      @dira = make_absolute('/a')
      @dirb = make_absolute('/b')
      @dirc = make_absolute('/c')
    end

    it "should collect all of the plugins and lib directories that exist in the current environment's module path" do
      Puppet.settings.expects(:value).with(:environment).returns "foo"
      Puppet.settings.expects(:value).with(:modulepath, :foo).returns "#{@dira}#{File::PATH_SEPARATOR}#{@dirb}#{File::PATH_SEPARATOR}#{@dirc}"
      Dir.expects(:entries).with(@dira).returns %w{one two}
      Dir.expects(:entries).with(@dirb).returns %w{one two}

      FileTest.stubs(:directory?).returns false
      FileTest.expects(:directory?).with(@dira).returns true
      FileTest.expects(:directory?).with(@dirb).returns true
      ["#{@dira}/one/plugins", "#{@dira}/two/lib", "#{@dirb}/one/plugins", "#{@dirb}/two/lib"].each do |d|
        FileTest.expects(:directory?).with(d).returns true
      end

      @autoload.module_directories.should == ["#{@dira}/one/plugins", "#{@dira}/two/lib", "#{@dirb}/one/plugins", "#{@dirb}/two/lib"]
    end

    it "should not look for lib directories in directories starting with '.'" do
      Puppet.settings.expects(:value).with(:environment).returns "foo"
      Puppet.settings.expects(:value).with(:modulepath, :foo).returns @dira
      Dir.expects(:entries).with(@dira).returns %w{. ..}

      FileTest.expects(:directory?).with(@dira).returns true
      FileTest.expects(:directory?).with("#{@dira}/./lib").never
      FileTest.expects(:directory?).with("#{@dira}/./plugins").never
      FileTest.expects(:directory?).with("#{@dira}/../lib").never
      FileTest.expects(:directory?).with("#{@dira}/../plugins").never

      @autoload.module_directories
    end

    it "should include the module directories, the Puppet libdir, and all of the Ruby load directories" do
      Puppet.stubs(:[]).with(:libdir).returns(%w{/libdir1 /lib/dir/two /third/lib/dir}.join(File::PATH_SEPARATOR))
      @autoload.expects(:module_directories).returns %w{/one /two}
      @autoload.search_directories.should == %w{/one /two /libdir1 /lib/dir/two /third/lib/dir} + $LOAD_PATH
    end

    it "should include in its search path all of the unique search directories that have a subdirectory matching the autoload path" do
      @autoload = Puppet::Util::Autoload.new("foo", "loaddir")
      @autoload.expects(:search_directories).returns %w{/one /two /three /three}
      FileTest.expects(:directory?).with("/one/loaddir").returns true
      FileTest.expects(:directory?).with("/two/loaddir").returns false
      FileTest.expects(:directory?).with("/three/loaddir").returns true
      @autoload.searchpath.should == ["/one/loaddir", "/three/loaddir"]
    end
  end

  it "should include its FileCache module" do
    Puppet::Util::Autoload.ancestors.should be_include(Puppet::Util::Autoload::FileCache)
  end

  describe "when loading a file" do
    before do
      @autoload.stubs(:searchpath).returns %w{/a}
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die with Puppet::Error if a #{error.to_s} exception is thrown" do
        @autoload.stubs(:file_exist?).returns true

        Kernel.expects(:load).raises error

        lambda { @autoload.load("foo") }.should raise_error(Puppet::Error)
      end
    end

    it "should not raise an error if the file is missing" do
      @autoload.load("foo").should == false
    end

    it "should register loaded files with the main loaded file list so they are not reloaded by ruby" do
      @autoload.stubs(:file_exist?).returns true
      Kernel.stubs(:load)

      @autoload.load("myfile")

      $LOADED_FEATURES.should be_include("tmp/myfile.rb")
    end
  end

  describe "when loading all files" do
    before do
      @autoload.stubs(:searchpath).returns %w{/a}
      Dir.stubs(:glob).returns "/path/to/file.rb"

      @autoload.class.stubs(:loaded?).returns(false)
    end

    [RuntimeError, LoadError, SyntaxError].each do |error|
      it "should die an if a #{error.to_s} exception is thrown", :'fails_on_ruby_1.9.2' => true do
        Kernel.expects(:require).raises error

        lambda { @autoload.loadall }.should raise_error(Puppet::Error)
      end
    end

    it "should require the full path to the file", :'fails_on_ruby_1.9.2' => true do
      Kernel.expects(:require).with("/path/to/file.rb")

      @autoload.loadall
    end
  end
end
