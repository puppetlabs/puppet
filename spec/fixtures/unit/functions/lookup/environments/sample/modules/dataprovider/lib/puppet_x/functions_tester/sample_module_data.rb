require 'puppet_x'
module PuppetX::FunctionsTester
  class SampleModuleData < Puppet::Plugins::DataProviders::ModuleDataProvider
    def initialize()
      @data = { 
        'dataprovider::test::param_a' => 'module data param_a is 100',
        'dataprovider::test::param_b' => 'module data param_b is 200',
        'dataprovider::test::param_c' => 'overriden env data param_c is 300',
      }
    end

    def lookup(name, scope, merge)
      @data[name]
    end
  end
end

