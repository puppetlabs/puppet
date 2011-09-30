#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/configurer/downloader'

describe Puppet::Configurer::Downloader do
  require 'puppet_spec/files'
  include PuppetSpec::Files
  it "should require a name" do
    lambda { Puppet::Configurer::Downloader.new }.should raise_error(ArgumentError)
  end

  it "should require a path and a source at initialization" do
    lambda { Puppet::Configurer::Downloader.new("name") }.should raise_error(ArgumentError)
  end

  it "should set the name, path and source appropriately" do
    dler = Puppet::Configurer::Downloader.new("facts", "path", "source")
    dler.name.should == "facts"
    dler.path.should == "path"
    dler.source.should == "source"
  end

  it "should be able to provide a timeout value" do
    Puppet::Configurer::Downloader.should respond_to(:timeout)
  end

  it "should use the configtimeout, converted to an integer, as its timeout" do
    Puppet.settings.expects(:value).with(:configtimeout).returns "50"
    Puppet::Configurer::Downloader.timeout.should == 50
  end

  describe "when creating the file that does the downloading" do
    before do
      @dler = Puppet::Configurer::Downloader.new("foo", "path", "source")
    end

    it "should create a file instance with the right path and source" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:path] == "path" and opts[:source] == "source" }
      @dler.file
    end

    it "should tag the file with the downloader name" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:tag] == "foo" }
      @dler.file
    end

    it "should always recurse" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:recurse] == true }
      @dler.file
    end

    it "should always purge" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:purge] == true }
      @dler.file
    end

    it "should never be in noop" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:noop] == false }
      @dler.file
    end

    it "should always set the owner to the current UID" do
      Process.expects(:uid).returns 51
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:owner] == 51 }
      @dler.file
    end

    it "should always set the group to the current GID" do
      Process.expects(:gid).returns 61
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:group] == 61 }
      @dler.file
    end

    it "should always force the download" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:force] == true }
      @dler.file
    end

    it "should never back up when downloading" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:backup] == false }
      @dler.file
    end

    it "should support providing an 'ignore' parameter" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:ignore] == [".svn"] }
      @dler = Puppet::Configurer::Downloader.new("foo", "path", "source", ".svn")
      @dler.file
    end

    it "should split the 'ignore' parameter on whitespace" do
      Puppet::Type.type(:file).expects(:new).with { |opts| opts[:ignore] == %w{.svn CVS} }
      @dler = Puppet::Configurer::Downloader.new("foo", "path", "source", ".svn CVS")
      @dler.file
    end
  end

  describe "when creating the catalog to do the downloading" do
    before do
      @path = File.expand_path("/download/path")
      @dler = Puppet::Configurer::Downloader.new("foo", @path, File.expand_path("source"))
    end

    it "should create a catalog and add the file to it" do
      catalog = @dler.catalog
      catalog.resources.size.should == 1
      catalog.resources.first.class.should == Puppet::Type::File
      catalog.resources.first.name.should == @path
    end

    it "should specify that it is not managing a host catalog" do
      @dler.catalog.host_config.should == false
    end

  end

  describe "when downloading" do
    before do
      @dl_name = tmpfile("downloadpath")
      source_name = tmpfile("source")
      File.open(source_name, 'w') {|f| f.write('hola mundo') }
      @dler = Puppet::Configurer::Downloader.new("foo", @dl_name, source_name)
    end

    it "should not skip downloaded resources when filtering on tags", :fails_on_windows => true do
      Puppet[:tags] = 'maytag'
      @dler.evaluate

      File.exists?(@dl_name).should be_true
    end

    it "should log that it is downloading" do
      Puppet.expects(:info)
      Timeout.stubs(:timeout)

      @dler.evaluate
    end

    it "should set a timeout for the download" do
      Puppet::Configurer::Downloader.expects(:timeout).returns 50
      Timeout.expects(:timeout).with(50)

      @dler.evaluate
    end

    it "should apply the catalog within the timeout block" do
      catalog = mock 'catalog'
      @dler.expects(:catalog).returns(catalog)

      Timeout.expects(:timeout).yields

      catalog.expects(:apply)

      @dler.evaluate
    end

    it "should return all changed file paths" do
      trans = mock 'transaction'

      catalog = mock 'catalog'
      @dler.expects(:catalog).returns(catalog)
      catalog.expects(:apply).yields(trans)

      Timeout.expects(:timeout).yields

      resource = mock 'resource'
      resource.expects(:[]).with(:path).returns "/changed/file"

      trans.expects(:changed?).returns([resource])

      @dler.evaluate.should == %w{/changed/file}
    end

    it "should yield the resources if a block is given" do
      trans = mock 'transaction'

      catalog = mock 'catalog'
      @dler.expects(:catalog).returns(catalog)
      catalog.expects(:apply).yields(trans)

      Timeout.expects(:timeout).yields

      resource = mock 'resource'
      resource.expects(:[]).with(:path).returns "/changed/file"

      trans.expects(:changed?).returns([resource])

      yielded = nil
      @dler.evaluate { |r| yielded = r }
      yielded.should == resource
    end

    it "should catch and log exceptions" do
      Puppet.expects(:err)
      Timeout.stubs(:timeout).raises(Puppet::Error, "testing")

      lambda { @dler.evaluate }.should_not raise_error
    end
  end
end
