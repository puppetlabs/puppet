#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/configurer/downloader'

describe Puppet::Configurer::Downloader do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  let(:path)   { Puppet[:plugindest] }
  let(:source) { 'puppet://puppet/plugins' }

  it "should require a name" do
    expect { Puppet::Configurer::Downloader.new }.to raise_error(ArgumentError)
  end

  it "should require a path and a source at initialization" do
    expect { Puppet::Configurer::Downloader.new("name") }.to raise_error(ArgumentError)
  end

  it "should set the name, path and source appropriately" do
    dler = Puppet::Configurer::Downloader.new("facts", "path", "source")
    expect(dler.name).to eq("facts")
    expect(dler.path).to eq("path")
    expect(dler.source).to eq("source")
  end

  def downloader(options = {})
    options[:name] ||= "facts"
    options[:path] ||= path
    options[:source_permissions] ||= :ignore
    Puppet::Configurer::Downloader.new(options[:name], options[:path], source, options[:ignore], options[:environment], options[:source_permissions])
  end

  def generate_file_resource(options = {})
    dler = downloader(options)
    dler.file
  end

  describe "when creating the file that does the downloading" do
    it "should create a file instance with the right path and source" do
      file = generate_file_resource(:path => path, :source => source)

      expect(file[:path]).to eq(path)
      expect(file[:source]).to eq([source])
    end

    it "should tag the file with the downloader name" do
      name = "mydownloader"
      file = generate_file_resource(:name => name)

      expect(file[:tag]).to eq([name])
    end

    it "should always recurse" do
      file = generate_file_resource

      expect(file[:recurse]).to be_truthy
    end

    it "should follow links by default" do
      file = generate_file_resource

      expect(file[:links]).to eq(:follow)
    end

    it "should always purge" do
      file = generate_file_resource

      expect(file[:purge]).to be_truthy
    end

    it "should never be in noop" do
      file = generate_file_resource

      expect(file[:noop]).to be_falsey
    end

    it "should set source_permissions to ignore by default" do
      file = generate_file_resource

      expect(file[:source_permissions]).to eq(:ignore)
    end

    describe "on POSIX", :if => Puppet.features.posix? do
      it "should allow source_permissions to be overridden" do
        file = generate_file_resource(:source_permissions => :use)

        expect(file[:source_permissions]).to eq(:use)
      end

      it "should always set the owner to the current UID" do
        Process.expects(:uid).returns 51

        file = generate_file_resource(:path => '/path')
        expect(file[:owner]).to eq(51)
      end

      it "should always set the group to the current GID" do
        Process.expects(:gid).returns 61

        file = generate_file_resource(:path => '/path')
        expect(file[:group]).to eq(61)
      end
    end

    describe "on Windows", :if => Puppet.features.microsoft_windows? do
      it "should omit the owner" do
        file = generate_file_resource(:path => 'C:/path')

        expect(file[:owner]).to be_nil
      end

      it "should omit the group" do
        file = generate_file_resource(:path => 'C:/path')

        expect(file[:group]).to be_nil
      end
    end

    it "should always force the download" do
      file = generate_file_resource

      expect(file[:force]).to be_truthy
    end

    it "should never back up when downloading" do
      file = generate_file_resource

      expect(file[:backup]).to be_falsey
    end

    it "should support providing an 'ignore' parameter" do
      file = generate_file_resource(:ignore => '.svn')

      expect(file[:ignore]).to eq(['.svn'])
    end

    it "should split the 'ignore' parameter on whitespace" do
      file = generate_file_resource(:ignore => '.svn CVS')

      expect(file[:ignore]).to eq(['.svn', 'CVS'])
    end
  end

  describe "when creating the catalog to do the downloading" do
    before do
      @path = make_absolute("/download/path")
      @dler = Puppet::Configurer::Downloader.new("foo", @path, make_absolute("source"))
    end

    it "should create a catalog and add the file to it" do
      catalog = @dler.catalog
      expect(catalog.resources.size).to eq(1)
      expect(catalog.resources.first.class).to eq(Puppet::Type::File)
      expect(catalog.resources.first.name).to eq(@path)
    end

    it "should specify that it is not managing a host catalog" do
      expect(@dler.catalog.host_config).to eq(false)
    end

  end

  describe "when downloading" do
    before do
      @dl_name = tmpfile("downloadpath")
      source_name = tmpfile("source")
      File.open(source_name, 'w') {|f| f.write('hola mundo') }
      env = Puppet::Node::Environment.remote('foo')
      @dler = Puppet::Configurer::Downloader.new("foo", @dl_name, source_name, Puppet[:pluginsignore], env)
    end

    it "should not skip downloaded resources when filtering on tags" do
      Puppet[:tags] = 'maytag'
      @dler.evaluate

      expect(Puppet::FileSystem.exist?(@dl_name)).to be_truthy
    end

    it "should log that it is downloading" do
      Puppet.expects(:info)

      @dler.evaluate
    end

    it "should return all changed file paths" do
      trans = mock 'transaction'

      catalog = mock 'catalog'
      @dler.expects(:catalog).returns(catalog)
      catalog.expects(:apply).yields(trans)

      resource = mock 'resource'
      resource.expects(:[]).with(:path).returns "/changed/file"

      trans.expects(:changed?).returns([resource])

      expect(@dler.evaluate).to eq(%w{/changed/file})
    end

    it "should yield the resources if a block is given" do
      trans = mock 'transaction'

      catalog = mock 'catalog'
      @dler.expects(:catalog).returns(catalog)
      catalog.expects(:apply).yields(trans)

      resource = mock 'resource'
      resource.expects(:[]).with(:path).returns "/changed/file"

      trans.expects(:changed?).returns([resource])

      yielded = nil
      @dler.evaluate { |r| yielded = r }
      expect(yielded).to eq(resource)
    end

    it "should catch and log exceptions" do
      Puppet.expects(:err)
      # The downloader creates a new catalog for each apply, and really the only object
      # that it is possible to stub for the purpose of generating a puppet error
      Puppet::Resource::Catalog.any_instance.stubs(:apply).raises(Puppet::Error, "testing")

      expect { @dler.evaluate }.not_to raise_error
    end
  end
end
