#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

describe "when using a sample data provider from an external module" do
  include PuppetSpec::Compiler

  # There is a fully configured 'sample' environment in fixtures at this location
  let(:environmentpath) { parent_fixture('environments') }

  around(:each) do |example|
    # Initialize settings to get a full compile as close as possible to a real
    # environment load
    Puppet.settings.initialize_global_settings
    # Initialize loaders based on the environmentpath. It does not work to
    # just set the setting environmentpath for some reason - this achieves the same:
    # - first a loader is created, loading directory environments from the fixture (there is
    # one environment, 'sample', which will be loaded since the node references this
    # environment by name).
    # - secondly, the created env loader is set as 'environments' in the puppet context.
    #
    loader = Puppet::Environments::Directories.new(environmentpath, [])
    Puppet.override(:environments => loader) do
      example.run
    end
  end

  it 'the environment data loader is used to set parameters' do
    node = Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", {}), :environment => 'sample')
    compiler = Puppet::Parser::Compiler.new(node)
    catalog = compiler.compile()
    resources_created_in_fixture = ["Notify[env data param_a is 10, env data param_b is 20, 3]"]
    expect(resources_in(catalog)).to include(*resources_created_in_fixture)
  end

  it 'the module and environment data loader is used to set parameters' do
    node = Puppet::Node.new("testnode", :facts => Puppet::Node::Facts.new("facts", {}), :environment => 'sample')
    compiler = Puppet::Parser::Compiler.new(node)
    catalog = compiler.compile()
    resources_created_in_fixture = ["Notify[module data param_a is 100, module data param_b is 200, env data param_c is 300]"]
    expect(resources_in(catalog)).to include(*resources_created_in_fixture)
  end

  def parent_fixture(dir_name)
    File.absolute_path(File.join(my_fixture_dir(), "../#{dir_name}"))
  end

  def resources_in(catalog)
    catalog.resources.map(&:ref)
  end

end
