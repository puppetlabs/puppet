require 'spec_helper'
require 'puppet/pops'

describe "Hiera2 YAML backend" do

  include PuppetSpec::Files

  let(:_YamlBackend) {  Puppet::Pops::Binder::Hiera2::YamlBackend }

  def fixture_dir(config_name)
    my_fixture("#{config_name}")
  end

  it "returns the expected hash from a valid yaml file" do
    _YamlBackend.new().read_data(fixture_dir("ok"), "common").should == {'brillig' => 'slithy'}
  end

  it "returns an empty hash from an empty yaml file" do
    _YamlBackend.new().read_data(fixture_dir("empty"), "common").should == {}
  end

  it "returns an empty hash from an invalid yaml file" do
    _YamlBackend.new().read_data(fixture_dir("invalid"), "common").should == {}
  end
end
