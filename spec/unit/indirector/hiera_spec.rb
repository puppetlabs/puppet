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

  let(:request_integer) do
    stub('request', :key => "integer", :options => options)
  end

  let(:request_string) do
    stub('request', :key => "string", :options => options)
  end

  let(:request_array) do
    stub('request', :key => "array", :options => options)
  end

  let(:request_hash) do
    stub('request', :key => "hash", :options => options)
  end

  let(:indirection) do
    stub('indirection', :name => :none, :register_terminus_type => nil,
      :model => model)
  end

  let(:facts) do
    { 'fqdn' => 'agent.testing.com' }
  end
  let(:facter_obj) { stub(:values => facts) }

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

  describe "the behavior of the hiera_config method", :if => Puppet.features.hiera? do
    let(:default_hiera_config) do
      {
        :logger    => "puppet",
        :backends  => ["yaml"],
        :yaml      => { :datadir => datadir },
        :hierarchy => ["global"]
      }
    end

    it "should load the hiera config file by delegating to Hiera" do
      Hiera::Config.expects(:load).with(hiera_config_file).returns({})
      @hiera_class.hiera_config
    end

    it "should override the logger and set it to puppet" do
      @hiera_class.hiera_config[:logger].should == "puppet"
    end

    it "should return a hiera configuration hash" do
      results = @hiera_class.hiera_config
      default_hiera_config.each do |key,value|
        results[key].should == value
      end
      results.should be_a_kind_of Hash
    end

    context "when the Hiera configuration file does not exist" do
      let(:path) { File.expand_path('/doesnotexist') }

      before do
        Puppet.settings[:hiera_config] = path
      end

      it "should log a warning" do
        Puppet.expects(:warning).with(
         "Config file #{path} not found, using Hiera defaults")
        @hiera_class.hiera_config
      end

      it "should only configure the logger and set it to puppet" do
        Puppet.expects(:warning).with(
         "Config file #{path} not found, using Hiera defaults")
        @hiera_class.hiera_config.should == { :logger => 'puppet' }
      end
    end
  end

  describe "the behavior of the find method", :if => Puppet.features.hiera? do

    let(:data_binder) { @hiera_class.new }

    it "should support looking up an integer" do
      data_binder.find(request_integer).should == 3000
    end

    it "should support looking up a string" do
      data_binder.find(request_string).should == 'apache'
    end

    it "should support looking up an array" do
      data_binder.find(request_array).should == [
        '0.ntp.puppetlabs.com',
        '1.ntp.puppetlabs.com',
      ]
    end

    it "should support looking up a hash" do
      data_binder.find(request_hash).should == {
        'user'  => 'Hightower',
        'group' => 'admin',
        'mode'  => '0644'
      }
    end
  end
end

