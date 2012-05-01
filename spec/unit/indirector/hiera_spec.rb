require 'spec_helper'
require 'puppet/indirector/hiera'

describe Puppet::Indirector::Hiera do
  before do
    Puppet.settings[:hiera_config] = {}
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    Puppet::Indirector::Indirection.stubs(:instance).returns(indirection)

    module Testing; end
    @hiera_class = class Testing::Hiera < Puppet::Indirector::Hiera
      self
    end
  end

  let(:model)   { mock('model') }
  let(:options) { {:host => 'foo' } }
  let(:request) { stub('request', :key => "port", :options => options) }
  let(:indirection) do
    stub('indirection', :name => :none, :register_terminus_type => nil,
      :model => model)
  end

  let(:facts) do
    { 'fqdn' => 'agent.testing.com' }
  end
  let(:facter_obj) { stub(:values => facts) }

  it "should not be the default data_binding terminus" do
    Puppet.settings[:data_binding_terminus].should_not == 'hiera'
  end

  it "should raise an error if we don't have the hiera feature" do
    Puppet.features.expects(:hiera?).returns(false)
    lambda { @hiera_class.new }.should raise_error RuntimeError,
      "Hiera terminus not supported without hiera gem"
  end

  describe "the behavior of the find method" do
    it "should lookup the requested key in hiera", :if => Puppet.features.hiera? do
      Hiera.any_instance.expects(:lookup).with("port", nil, facts, nil, nil).returns('3000')
      Puppet::Node::Facts.indirection.expects(:find).with('foo').returns(facter_obj)

      data_binder = @hiera_class.new
      data_binder.find(request).should == '3000'
    end
  end
end
