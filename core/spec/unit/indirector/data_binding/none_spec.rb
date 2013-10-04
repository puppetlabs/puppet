require 'spec_helper'
require 'puppet/indirector/data_binding/none'

describe Puppet::DataBinding::None do
  it "should be a subclass of the None terminus" do
    Puppet::DataBinding::None.superclass.should equal(Puppet::Indirector::None)
  end

  it "should have documentation" do
    Puppet::DataBinding::None.doc.should_not be_nil
  end

  it "should be registered with the data_binding indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:data_binding)
    Puppet::DataBinding::None.indirection.should equal(indirection)
  end

  it "should have its name set to :none" do
    Puppet::DataBinding::None.name.should == :none
  end

  describe "the behavior of the find method" do
    it "should just return nil" do
      data_binding = Puppet::DataBinding::None.new
      data_binding.find('fake_request').should be_nil
    end
  end
end
