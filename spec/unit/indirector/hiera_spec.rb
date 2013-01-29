require 'spec_helper'
require 'puppet/indirector/hiera'
require 'hiera/backend'

describe Puppet::Indirector::Hiera do
  include PuppetSpec::Files

  def write_hiera_config(config_file, datadir)
    File.open(config_file, 'w') do |f|
      f.write("---
        :yaml:
          :datadir: #{datadir}
        :hierarchy: ['global']
        :logger: 'noop'
        :backends: ['yaml']
      ")
    end
  end

  before do
    Puppet.settings[:hiera_config] = hiera_config_file
    write_hiera_config(hiera_config_file, datadir)

    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    Puppet::Indirector::Indirection.stubs(:instance).returns(indirection)

    module Testing; end
    @hiera_class = class Testing::Hiera < Puppet::Indirector::Hiera
      self
    end
  end

  let(:model)   { mock('model') }
  let(:options) { {:host => 'foo' } }

  let(:request_string) do
    stub('request', :key => "string", :options => options)
  end

  let(:indirection) do
    stub('indirection', :name => :none, :register_terminus_type => nil,
      :model => model)
  end

  let(:hiera_config_file) do
    tmpfile("hiera.yaml")
  end

  let(:datadir) { my_fixture_dir }

  it "should be the default data_binding terminus" do
    Puppet.settings[:data_binding_terminus].should == :hiera
  end

  it "should raise an error if we don't have the hiera feature" do
    Puppet.features.expects(:hiera?).returns(false)
    lambda { @hiera_class.new }.should raise_error RuntimeError,
      "Hiera terminus not supported without hiera library"
  end

  describe "the behavior of the find method", :if => Puppet.features.hiera? do
    let(:data_binder) { @hiera_class.new }

    it "should look up the data using the HieraPuppet helper" do
      HieraPuppet.expects(:lookup).with("string", nil, nil, nil, nil)
      data_binder.find(request_string)
    end
  end
end

