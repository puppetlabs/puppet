require 'spec_helper'
require 'puppet/data_binding'

describe Puppet::DataBinding do
  describe "when indirecting" do
    it "should default to the 'hiera' data_binding terminus" do
      Puppet::DataBinding.indirection.reset_terminus_class
      Puppet::DataBinding.indirection.terminus_class.should == :hiera
    end
  end
end
