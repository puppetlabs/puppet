require 'spec_helper'
require 'puppet/indirector/data_binding/hiera'

describe Puppet::DataBinding::Hiera do
  it "should have documentation" do
    expect(Puppet::DataBinding::Hiera.doc).not_to be_nil
  end

  it "should be registered with the data_binding indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:data_binding)
    expect(Puppet::DataBinding::Hiera.indirection).to equal(indirection)
  end

  it "should have its name set to :hiera" do
    expect(Puppet::DataBinding::Hiera.name).to eq(:hiera)
  end

  it_should_behave_like "Hiera indirection", Puppet::DataBinding::Hiera, my_fixture_dir
end
