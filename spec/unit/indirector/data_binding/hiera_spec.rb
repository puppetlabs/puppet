require 'spec_helper'
require 'puppet/indirector/data_binding/hiera'

describe Puppet::DataBinding::Hiera do
  it "should have documentation" do
    Puppet::DataBinding::Hiera.doc.should_not be_nil
  end

  it "should be registered with the data_binding indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:data_binding)
    Puppet::DataBinding::Hiera.indirection.should equal(indirection)
  end

  it "should have its name set to :hiera" do
    Puppet::DataBinding::Hiera.name.should == :hiera
  end

  it_should_behave_like "Hiera indirection", Puppet::DataBinding::Hiera, my_fixture_dir
end
