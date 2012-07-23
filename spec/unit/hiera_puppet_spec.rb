require 'spec_helper'

describe 'HieraPuppet' do
  describe 'HieraPuppet#hiera_config' do
    let(:hiera_config_data) do
      { :backend => 'yaml' }
    end

    context "when the hiera_config_file exists" do
      before do
        Hiera::Config.expects(:load).returns(hiera_config_data)
        HieraPuppet.expects(:hiera_config_file).returns(true)
      end

      it "should return a configuration hash" do
        expected_results = {
          :backend => 'yaml',
          :logger  => 'puppet'
        }
        HieraPuppet.send(:hiera_config).should == expected_results
      end
    end

    context "when the hiera_config_file does not exist" do
      before do
        Hiera::Config.expects(:load).never
        HieraPuppet.expects(:hiera_config_file).returns(nil)
      end

      it "should return a configuration hash" do
        HieraPuppet.send(:hiera_config).should == { :logger => 'puppet' }
      end
    end
  end

  describe 'HieraPuppet#hiera_config_file' do
    it "should return nil when we cannot derive the hiera config file form Puppet.settings" do
      begin
        Puppet.settings[:hiera_config] = nil
      rescue ArgumentError => detail
        raise unless detail.message =~ /unknown configuration parameter/
      end
      HieraPuppet.send(:hiera_config_file).should be_nil
    end

    it "should use Puppet.settings[:hiera_config] as the hiera config file" do
      begin
        Puppet.settings[:hiera_config] = "/dev/null/my_hiera.yaml"
      rescue ArgumentError => detail
        raise unless detail.message =~ /unknown configuration parameter/
        pending("This example does not apply to Puppet #{Puppet.version} because it does not have this setting")
      end

      File.stubs(:exist?).with("/dev/null/my_hiera.yaml").returns(true)
      HieraPuppet.send(:hiera_config_file).should == '/dev/null/my_hiera.yaml'
    end

    it "should use Puppet.settings[:confdir] as the base directory when hiera_config is not set" do
      begin
        Puppet.settings[:hiera_config] = nil
      rescue ArgumentError => detail
        raise unless detail.message =~ /unknown configuration parameter/
      end
      Puppet.settings[:confdir] = "/dev/null/puppet"
      File.stubs(:exist?).with('/dev/null/puppet/hiera.yaml').returns(true)

      HieraPuppet.send(:hiera_config_file).should == '/dev/null/puppet/hiera.yaml'
    end
  end

  describe 'HieraPuppet#lookup' do
    let(:scope) { PuppetlabsSpec::PuppetInternals.scope }

    it "should return the value from Hiera" do
      Hiera.any_instance.stubs(:lookup).returns('8080')
      HieraPuppet.lookup('port', nil, scope, nil, :priority).should == '8080'

      Hiera.any_instance.stubs(:lookup).returns(['foo', 'bar'])
      HieraPuppet.lookup('ntpservers', nil, scope, nil, :array).should == ['foo', 'bar']

      Hiera.any_instance.stubs(:lookup).returns({'uid' => '1000'})
      HieraPuppet.lookup('user', nil, scope, nil, :hash).should == {'uid' => '1000'}
    end

    it "should raise a useful error when the answer is nil" do
      Hiera.any_instance.stubs(:lookup).returns(nil)
      expect do
        HieraPuppet.lookup('port', nil, scope, nil, :priority)
      end.to raise_error(Puppet::ParseError,
        /Could not find data item port in any Hiera data file and no default supplied/)
    end
  end

  describe 'HieraPuppet#parse_args' do
    it 'should return a 3 item array' do
      args = ['foo', '8080', nil, nil]
      HieraPuppet.parse_args(args).should == ['foo', '8080', nil]
    end

    it 'should raise a useful error when no key is supplied' do
      expect { HieraPuppet.parse_args([]) }.to raise_error(Puppet::ParseError,
        /Please supply a parameter to perform a Hiera lookup/)
    end
  end
end
