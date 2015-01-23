#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_metadata/file_server'
require 'shared_behaviours/file_server_terminus'

require 'puppet_spec/files'

describe Puppet::Indirector::FileMetadata::FileServer, " when finding files" do
  it_should_behave_like "Puppet::Indirector::FileServerTerminus"
  include PuppetSpec::Files

  before do
    @terminus = Puppet::Indirector::FileMetadata::FileServer.new
    @test_class = Puppet::FileServing::Metadata
    Puppet::FileServing::Configuration.instance_variable_set(:@configuration, nil)
  end

  it "should find plugin file content in the environment specified in the request" do
    path = tmpfile("file_content_with_env")

    Dir.mkdir(path)

    modpath = File.join(path, "mod")
    FileUtils.mkdir_p(File.join(modpath, "lib"))
    file = File.join(modpath, "lib", "file.rb")
    File.open(file, "wb") { |f| f.write "1\r\n" }

    Puppet.settings[:modulepath] = "/no/such/file"

    env = Puppet::Node::Environment.create(:foo, [path])

    result = Puppet::FileServing::Metadata.indirection.search("plugins", :environment => env, :recurse => true)

    result.should_not be_nil
    result.length.should == 2
    result.map {|x| x.should be_instance_of(Puppet::FileServing::Metadata) }
    result.find {|x| x.relative_path == 'file.rb' }.checksum.should == "{md5}a5ea0ad9260b1550a14cc58d2c39b03d"
  end

  it "should find file metadata in modules" do
    path = tmpfile("file_content")

    Dir.mkdir(path)

    modpath = File.join(path, "mymod")
    FileUtils.mkdir_p(File.join(modpath, "files"))
    file = File.join(modpath, "files", "myfile")
    File.open(file, "wb") { |f| f.write "1\r\n" }

    env = Puppet::Node::Environment.create(:foo, [path])

    result = Puppet::FileServing::Metadata.indirection.find("modules/mymod/myfile", :environment => env)

    result.should_not be_nil
    result.should be_instance_of(Puppet::FileServing::Metadata)
    result.checksum.should == "{md5}a5ea0ad9260b1550a14cc58d2c39b03d"
  end

  it "should find file content in files when node name expansions are used" do
    Puppet::FileSystem.stubs(:exist?).returns true
    Puppet::FileSystem.stubs(:exist?).with(Puppet[:fileserverconfig]).returns(true)

    path = tmpfile("file_server_testing")

    Dir.mkdir(path)
    subdir = File.join(path, "mynode")
    Dir.mkdir(subdir)
    File.open(File.join(subdir, "myfile"), "wb") { |f| f.write "1\r\n" }

    # Use a real mount, so the integration is a bit deeper.
    mount1 = Puppet::FileServing::Configuration::Mount::File.new("one")
    mount1.stubs(:allowed?).returns true
    mount1.path = File.join(path, "%h")

    parser = stub 'parser', :changed? => false
    parser.stubs(:parse).returns("one" => mount1)

    Puppet::FileServing::Configuration::Parser.stubs(:new).returns(parser)

    path = File.join(path, "myfile")

    env = Puppet::Node::Environment.create(:foo, [])

    result = Puppet::FileServing::Metadata.indirection.find("one/myfile", :environment => env, :node => "mynode")

    result.should_not be_nil
    result.should be_instance_of(Puppet::FileServing::Metadata)
    result.checksum.should == "{md5}a5ea0ad9260b1550a14cc58d2c39b03d"
  end
end
