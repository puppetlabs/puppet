require 'puppet_x'
module PuppetX::FunctionsTester

  class SampleEnvData < Puppet::Plugins::DataProviders::EnvironmentDataProvider
    def initialize()
      @data = { 
        'test::param_a' => 'env data param_a is 10',
        'test::param_b' => 'env data param_b is 20',
        'dataprovider::test::param_c' => 'env data param_c is 300',
      }
    end

    def lookup(name, scope, merge)
      @data[name]
    end
  end
end

