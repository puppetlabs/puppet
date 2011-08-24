#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/file_content/file_server'
require 'shared_behaviours/file_server_terminus'

require 'puppet_spec/files'

describe Puppet::Indirector::FileContent::FileServer, " when finding files", :fails_on_windows => true do
  it_should_behave_like "Puppet::Indirector::FileServerTerminus"
  include PuppetSpec::Files

  before do
    @terminus = Puppet::Indirector::FileContent::FileServer.new
    @test_class = Puppet::FileServing::Content
    Puppet::FileServing::Configuration.instance_variable_set(:@configuration, nil)
  end

  it "should find plugin file content in the environment specified in the request" do
    path = tmpfile("file_content_with_env")

    Dir.mkdir(path)

    modpath = File.join(path, "mod")
    FileUtils.mkdir_p(File.join(modpath, "lib"))
    file = File.join(modpath, "lib", "file.rb")
    File.open(file, "w") { |f| f.puts "1" }

    Puppet.settings[:modulepath] = "/no/such/file"

    env = Puppet::Node::Environment.new("foo")
    env.stubs(:modulepath).returns [path]

    result = Puppet::FileServing::Content.indirection.search("plugins", :environment => "foo", :recurse => true)

    result.should_not be_nil
    result.length.should == 2
    result[1].should be_instance_of(Puppet::FileServing::Content)
    result[1].content.should == "1\n"
  end

  it "should find file content in modules" do
    path = tmpfile("file_content")

    Dir.mkdir(path)

    modpath = File.join(path, "mymod")
    FileUtils.mkdir_p(File.join(modpath, "files"))
    file = File.join(modpath, "files", "myfile")
    File.open(file, "w") { |f| f.puts "1" }

    Puppet.settings[:modulepath] = path

    result = Puppet::FileServing::Content.indirection.find("modules/mymod/myfile")

    result.should_not be_nil
    result.should be_instance_of(Puppet::FileServing::Content)
    result.content.should == "1\n"
  end

  it "should find file content in files when node name expansions are used" do
    FileTest.stubs(:exists?).returns true
    FileTest.stubs(:exists?).with(Puppet[:fileserverconfig]).returns(true)

    @path = tmpfile("file_server_testing")

    Dir.mkdir(@path)
    subdir = File.join(@path, "mynode")
    Dir.mkdir(subdir)
    File.open(File.join(subdir, "myfile"), "w") { |f| f.puts "1" }

    # Use a real mount, so the integration is a bit deeper.
    @mount1 = Puppet::FileServing::Configuration::Mount::File.new("one")
    @mount1.stubs(:allowed?).returns true
    @mount1.path = File.join(@path, "%h")

    @parser = stub 'parser', :changed? => false
    @parser.stubs(:parse).returns("one" => @mount1)

    Puppet::FileServing::Configuration::Parser.stubs(:new).returns(@parser)

    path = File.join(@path, "myfile")

    result = Puppet::FileServing::Content.indirection.find("one/myfile", :environment => "foo", :node => "mynode")

    result.should_not be_nil
    result.should be_instance_of(Puppet::FileServing::Content)
    result.content.should == "1\n"
  end
end
