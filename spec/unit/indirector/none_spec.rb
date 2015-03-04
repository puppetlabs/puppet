require 'spec_helper'
require 'puppet/indirector/none'

describe Puppet::Indirector::None do
  before do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    Puppet::Indirector::Indirection.stubs(:instance).returns(indirection)

    module Testing; end
    @none_class = class Testing::None < Puppet::Indirector::None
      self
    end

    @data_binder = @none_class.new
  end

  let(:model)   { mock('model') }
  let(:request) { stub('request', :key => "port") }
  let(:indirection) do
    stub('indirection', :name => :none, :register_terminus_type => nil,
      :model => model)
  end

  it "should not be the default data_binding_terminus" do
    expect(Puppet.settings[:data_binding_terminus]).not_to eq('none')
  end

  describe "the behavior of the find method" do
    it "should just return nil" do
      expect(@data_binder.find(request)).to be_nil
    end
  end
end
