require 'spec_helper'

require 'puppet/indirector/file_metadata/file_server'
require 'shared_behaviours/file_server_terminus'

require 'puppet_spec/files'

describe Puppet::Indirector::FileMetadata::FileServer, " when finding files" do
  it_should_behave_like "Puppet::Indirector::FileServerTerminus"
  include PuppetSpec::Files
  include_context 'with supported checksum types'

  before do
    @terminus = Puppet::Indirector::FileMetadata::FileServer.new
    @test_class = Puppet::FileServing::Metadata
    Puppet::FileServing::Configuration.instance_variable_set(:@configuration, nil)
  end

  describe "with a plugin environment specified in the request" do
    with_checksum_types("file_content_with_env", "mod/lib/file.rb") do
      it "should return the correct metadata" do
        Puppet.settings[:modulepath] = "/no/such/file"
        env = Puppet::Node::Environment.create(:foo, [env_path])
        result = Puppet::FileServing::Metadata.indirection.search("plugins", :environment => env, :checksum_type => checksum_type, :recurse => true)

        expect(result).to_not be_nil
        expect(result.length).to eq(2)
        result.map {|x| expect(x).to be_instance_of(Puppet::FileServing::Metadata)}
        expect_correct_checksum(result.find {|x| x.relative_path == 'file.rb'}, checksum_type, checksum, Puppet::FileServing::Metadata)
      end
    end
  end

  describe "in modules" do
    with_checksum_types("file_content", "mymod/files/myfile") do
      it "should return the correct metadata" do
        env = Puppet::Node::Environment.create(:foo, [env_path])
        result = Puppet::FileServing::Metadata.indirection.find("modules/mymod/myfile", :environment => env, :checksum_type => checksum_type)
        expect_correct_checksum(result, checksum_type, checksum, Puppet::FileServing::Metadata)
      end
    end
  end

  describe "that are tasks in modules" do
    with_checksum_types("task_file_content", "mymod/tasks/mytask") do
      it "should return the correct metadata" do
        env = Puppet::Node::Environment.create(:foo, [env_path])
        result = Puppet::FileServing::Metadata.indirection.find("tasks/mymod/mytask", :environment => env, :checksum_type => checksum_type)
        expect_correct_checksum(result, checksum_type, checksum, Puppet::FileServing::Metadata)
      end
    end
  end

  describe "when node name expansions are used" do
    with_checksum_types("file_server_testing", "mynode/myfile") do
      it "should return the correct metadata" do
        allow(Puppet::FileSystem).to receive(:exist?).with(checksum_file).and_return(true)
        allow(Puppet::FileSystem).to receive(:exist?).with(Puppet[:fileserverconfig]).and_return(true)

        # Use a real mount, so the integration is a bit deeper.
        mount1 = Puppet::FileServing::Configuration::Mount::File.new("one")
        mount1.path = File.join(env_path, "%h")

        parser = double('parser', :changed? => false)
        allow(parser).to receive(:parse).and_return("one" => mount1)

        allow(Puppet::FileServing::Configuration::Parser).to receive(:new).and_return(parser)
        env = Puppet::Node::Environment.create(:foo, [])

        result = Puppet::FileServing::Metadata.indirection.find("one/myfile", :environment => env, :node => "mynode", :checksum_type => checksum_type)
        expect_correct_checksum(result, checksum_type, checksum, Puppet::FileServing::Metadata)
      end
    end
  end
end
