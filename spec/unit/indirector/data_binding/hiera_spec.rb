require 'spec_helper'
require 'puppet/indirector/data_binding/hiera'

describe Puppet::DataBinding::Hiera do
  it "should be a subclass of the Hiera terminus" do
    Puppet::DataBinding::Hiera.superclass.should equal(Puppet::Indirector::Hiera)
  end

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
end
