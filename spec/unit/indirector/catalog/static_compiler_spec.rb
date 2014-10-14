#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector/catalog/static_compiler'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'
require 'yaml'

describe Puppet::Resource::Catalog::StaticCompiler do
  before :all do
    @num_file_resources = 10
  end

  before :each do
    Facter.stubs(:loadfacts)
    Facter.stubs(:to_hash).returns({})
    Facter.stubs(:value)
  end

  around(:each) do |example|
    Puppet.override({
        :current_environment => Puppet::Node::Environment.create(:app, []),
      },
      "Ensure we are using an environment other than root"
    ) do
      example.run
    end
  end

  let(:request) do
    Puppet::Indirector::Request.new(:the_indirection_named_foo,
                                    :find,
                                    "the-node-named-foo",
                                    :environment => "production")
  end

  describe "#find" do
    it "returns a catalog" do
      subject.find(request).should be_a_kind_of(Puppet::Resource::Catalog)
    end

    it "returns nil if there is no compiled catalog" do
      subject.expects(:compile).returns(nil)
      subject.find(request).should be_nil
    end

    describe "a catalog with file resources containing source parameters with puppet:// URIs" do
      it "filters file resource source URI's to checksums" do
        stub_the_compiler
        resource_catalog = subject.find(request)
        resource_catalog.resources.each do |resource|
          next unless resource.type == "File"
          resource[:content].should == "{md5}361fadf1c712e812d198c4cab5712a79"
          resource[:source].should be_nil
        end
      end

      it "does not modify file resources with non-puppet:// URI's" do
        uri = "/this/is/not/a/puppet/uri.txt"
        stub_the_compiler(:source => uri)
        resource_catalog = subject.find(request)
        resource_catalog.resources.each do |resource|
          next unless resource.type == "File"
          resource[:content].should be_nil
          resource[:source].should == uri
        end
      end

      it "copies the owner, group and mode from the fileserer" do
        stub_the_compiler
        resource_catalog = subject.find(request)
        resource_catalog.resources.each do |resource|
          next unless resource.type == "File"
          resource[:owner].should == 0
          resource[:group].should == 0
          resource[:mode].should  == 420
        end
      end
    end
  end

  describe "(#15193) when storing content to the filebucket" do
    it "explicitly uses the indirection method" do

      # We expect the content to be retrieved from the FileServer ...
      fake_content = mock('FileServer Content')
      fake_content.expects(:content).returns("HELLO WORLD")

      # Mock the FileBucket to behave as if the file content does not exist.
      # NOTE, we're simulating the first call returning false, indicating the
      # file is not present, then all subsequent calls returning true.  This
      # mocked behavior is intended to replicate the real behavior of the same
      # file being stored to the filebucket multiple times.
      Puppet::FileBucket::File.indirection.
        expects(:find).times(@num_file_resources).
        returns(false).then.returns(true)

      Puppet::FileServing::Content.indirection.
        expects(:find).once.
        returns(fake_content)

      # Once retrived from the FileServer, we expect the file to be stored into
      # the FileBucket only once.  All of the file resources in the fake
      # catalog have the same content.
      Puppet::FileBucket::File.indirection.expects(:save).once.with do |file|
        file.contents == "HELLO WORLD"
      end

      # Obtain the Static Catalog
      subject.stubs(:compile).returns(build_catalog)
      resource_catalog = subject.find(request)

      # Ensure all of the file resources were filtered
      resource_catalog.resources.each do |resource|
        next unless resource.type == "File"
        resource[:content].should == "{md5}361fadf1c712e812d198c4cab5712a79"
        resource[:source].should be_nil
      end
    end
  end

  # Spec helper methods

  def stub_the_compiler(options = {:stub_methods => [:store_content]})
    # Build a resource catalog suitable for specifying the behavior of the
    # static compiler.
    compiler = mock('indirection terminus compiler')
    compiler.stubs(:find).returns(build_catalog(options))
    subject.stubs(:compiler).returns(compiler)
    # Mock the store content method to prevent copying the contents to the
    # file bucket.
    (options[:stub_methods] || []).each do |mthd|
      subject.stubs(mthd)
    end
  end

  def build_catalog(options = {})
    options = options.dup
    options[:source] ||= 'puppet:///modules/mymodule/config_file.txt'
    options[:request] ||= request

    # Build a catalog suitable for the static compiler to operate on
    environment = Puppet::Node::Environment.remote(:testing)
    catalog = Puppet::Resource::Catalog.new("#{options[:request].key}", environment)

    # Mock out the fileserver, otherwise converting the catalog to a
    fake_fileserver_metadata = fileserver_metadata(options)

    # Stub the call to the FileServer metadata API so we don't have to have
    # a real fileserver initialized for testing.
    Puppet::FileServing::Metadata.
      indirection.stubs(:find).with do |uri, opts|
        expect(uri).to eq options[:source].sub('puppet:///','')
        expect(opts[:links]).to eq :manage
        expect(opts[:environment]).to eq environment
      end.returns(fake_fileserver_metadata)

    # I want a resource that all the file resources require and another
    # that requires them.
    resources = Array.new
    resources << Puppet::Resource.new("notify", "alpha")
    resources << Puppet::Resource.new("notify", "omega")

    # Create some File resources with source parameters.
    1.upto(@num_file_resources) do |idx|
      parameters = {
        :ensure  => 'file',
        :source  => options[:source],
        :require => "Notify[alpha]",
        :before  => "Notify[omega]"
      }
      # The static compiler does not operate on a RAL catalog, so we're
      # using Puppet::Resource to produce a resource catalog.
      agnostic_path = File.expand_path("/tmp/file_#{idx}.txt") # Windows Friendly
      rsrc = Puppet::Resource.new("file", agnostic_path, :parameters => parameters)
      rsrc.file = 'site.pp'
      rsrc.line = idx
      resources << rsrc
    end

    resources.each do |rsrc|
      catalog.add_resource(rsrc)
    end

    # Return the resource catalog
    catalog
  end

  describe "(#22744) when filtering resources" do
    let(:catalog) { stub_everything 'catalog' }

    it "should delegate to the catalog instance filtering" do
      catalog.expects(:filter)
      subject.filter(catalog)
    end

    it "should filter out virtual resources" do
      resource = mock 'resource', :virtual? => true
      catalog.stubs(:filter).yields(resource)

      subject.filter(catalog)
    end

    it "should return the same catalog if it doesn't support filtering" do
      catalog.stubs(:respond_to?).with(:filter)
      subject.filter(catalog).should == catalog
    end

    it "should return the filtered catalog" do
      filtered_catalog = stub 'filtered catalog'
      catalog.stubs(:filter).returns(filtered_catalog)

      subject.filter(catalog).should == filtered_catalog
    end

  end

  def fileserver_metadata(options = {})
    yaml = <<EOFILESERVERMETADATA
--- !ruby/object:Puppet::FileServing::Metadata
  checksum: "{md5}361fadf1c712e812d198c4cab5712a79"
  checksum_type: md5
  destination:
  expiration: #{Time.now + 1800}
  ftype: file
  group: 0
  links: !ruby/sym manage
  mode: 420
  owner: 0
  path: #{File.expand_path('/etc/puppet/modules/mymodule/files/config_file.txt')}
  source: #{options[:source]}
  stat_method: !ruby/sym lstat
EOFILESERVERMETADATA
    # Return a deserialized metadata object suitable for returning from a stub.
    YAML.load(yaml)
  end
end

