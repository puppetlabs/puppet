require 'spec_helper'
require 'puppet/indirector/none'

describe Puppet::Indirector::None do
  before do
    allow(Puppet::Indirector::Terminus).to receive(:register_terminus_class)
    allow(Puppet::Indirector::Indirection).to receive(:instance).and_return(indirection)

    module Testing; end
    @none_class = class Testing::None < Puppet::Indirector::None
      self
    end

    @data_binder = @none_class.new
  end

  let(:model)   { double('model') }
  let(:request) { double('request', :key => "port") }
  let(:indirection) do
    double('indirection', :name => :none, :register_terminus_type => nil,
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
