require 'spec_helper'
require 'puppet/pops'

describe "Hiera2 YAML backend" do

  include PuppetSpec::Files

  def fixture_dir(config_name)
    my_fixture("#{config_name}")
  end

  before(:all) do
    Puppet[:binder] = true
    require 'puppetx'
    require 'puppet/pops/binder/hiera2/yaml_backend'
  end

  after(:all) do
    Puppet[:binder] = false
  end

  it "returns the expected hash from a valid yaml file" do
    Puppet::Pops::Binder::Hiera2::YamlBackend.new().read_data(fixture_dir("ok"), "common").should == {'brillig' => 'slithy'}
  end

  it "returns an empty hash from an empty yaml file" do
    Puppet::Pops::Binder::Hiera2::YamlBackend.new().read_data(fixture_dir("empty"), "common").should == {}
  end

  it "returns an empty hash from an invalid yaml file" do
    Puppet::Pops::Binder::Hiera2::YamlBackend.new().read_data(fixture_dir("invalid"), "common").should == {}
  end
end
