#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_content/file_server'
require 'shared_behaviours/file_server_terminus'

require 'puppet_spec/files'

describe Puppet::Indirector::FileContent::FileServer, " when finding files" do
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
    File.open(file, "wb") { |f| f.write "1\r\n" }

    Puppet.settings[:modulepath] = "/no/such/file"

    env = Puppet::Node::Environment.create(:foo, [path])

    result = Puppet::FileServing::Content.indirection.search("plugins", :environment => env, :recurse => true)

    expect(result).not_to be_nil
    expect(result.length).to eq(2)
    result.map {|x| expect(x).to be_instance_of(Puppet::FileServing::Content) }
    expect(result.find {|x| x.relative_path == 'file.rb' }.content).to eq("1\r\n")
  end

  it "should find file content in modules" do
    path = tmpfile("file_content")

    Dir.mkdir(path)

    modpath = File.join(path, "mymod")
    FileUtils.mkdir_p(File.join(modpath, "files"))
    file = File.join(modpath, "files", "myfile")
    File.open(file, "wb") { |f| f.write "1\r\n" }

    env = Puppet::Node::Environment.create(:foo, [path])

    result = Puppet::FileServing::Content.indirection.find("modules/mymod/myfile", :environment => env)

    expect(result).not_to be_nil
    expect(result).to be_instance_of(Puppet::FileServing::Content)
    expect(result.content).to eq("1\r\n")
  end

  it "should find file content of tasks in modules" do
    path = tmpfile("task_file_content")
    Dir.mkdir(path)

    modpath = File.join(path, "myothermod")
    FileUtils.mkdir_p(File.join(modpath, "tasks"))
    file = File.join(modpath, "tasks", "mytask")
    File.open(file, "wb") { |f| f.write "I'm a task" }

    env = Puppet::Node::Environment.create(:foo, [path])
    result = Puppet::FileServing::Content.indirection.find("tasks/myothermod/mytask", :environment => env)

    expect(result).not_to be_nil
    expect(result).to be_instance_of(Puppet::FileServing::Content)
    expect(result.content).to eq("I'm a task")
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
    mount1.stubs(:globalallow?).returns true
    mount1.stubs(:allowed?).returns true
    mount1.path = File.join(path, "%h")

    parser = stub 'parser', :changed? => false
    parser.stubs(:parse).returns("one" => mount1)

    Puppet::FileServing::Configuration::Parser.stubs(:new).returns(parser)

    path = File.join(path, "myfile")

    env = Puppet::Node::Environment.create(:foo, [])

    result = Puppet::FileServing::Content.indirection.find("one/myfile", :environment => env, :node => "mynode")

    expect(result).not_to be_nil
    expect(result).to be_instance_of(Puppet::FileServing::Content)
    expect(result.content).to eq("1\r\n")
  end
end
