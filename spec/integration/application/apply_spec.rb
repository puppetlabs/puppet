#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet/application/apply'

describe "apply" do
  include PuppetSpec::Files

  before :each do
    Puppet[:reports] = "none"
  end

  describe "when applying provided catalogs" do
    it "can apply catalogs provided in a file in pson" do
      file_to_create = tmpfile("pson_catalog")
      catalog = Puppet::Resource::Catalog.new
      resource = Puppet::Resource.new(:file, file_to_create, :parameters => {:content => "my stuff"})
      catalog.add_resource resource

      manifest = tmpfile("manifest")

      File.open(manifest, "w") { |f| f.print catalog.to_pson }

      puppet = Puppet::Application[:apply]
      puppet.options[:catalog] = manifest

      puppet.apply

      expect(Puppet::FileSystem.exist?(file_to_create)).to be_true
      expect(File.read(file_to_create)).to eq("my stuff")
    end
  end

  it "applies a given file even when a directory environment is specified" do
    manifest = tmpfile("manifest.pp")
    File.open(manifest, "w") do |f|
      f.puts <<-EOF
      notice('it was applied')
      EOF
    end

    env_loader = Puppet::Environments::Static.new(
      Puppet::Node::Environment.create(:special, [], '')
    )
    Puppet.override(:environments => env_loader) do
      Puppet[:environment] = 'special'
      puppet = Puppet::Application[:apply]
      puppet.stubs(:command_line).returns(stub('command_line', :args => [manifest]))
      expect { puppet.run_command }.to exit_with(0)
    end

    expect(@logs.map(&:to_s)).to include('it was applied')
  end
end
