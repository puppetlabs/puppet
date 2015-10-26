# The module is named after the author, to ensure that names under PuppetX namespace
# does not clash.
#
require 'puppet_x'
module PuppetX::Helindbe

  # An env data provider that is hardcoded and provides data for
  # the two names 'test::param_a' and 'test::param_b'.
  #
  # A real implementation would read the data from somewhere or invoke some
  # other service to obtain the data. When doing so caching may be performance
  # critical, and it is important that a cache is associated with the apropriate
  # object to not cause memory leaks. See more details in the documentation
  # for how to write a data provider and use adapters.
  #
  class SampleEnvData < Puppet::Plugins::DataProviders::EnvironmentDataProvider
    def initialize()
      @data = { 
        'test::param_a' => 'env data param_a is 10',
        'test::param_b' => 'env data param_b is 20',
        # demo: this overrides a parameter for a class in the dataprovider module
        'dataprovider::test::param_c' => 'env data param_c is 300',
      }
    end

    def lookup(name, scope, merge)
      throw :no_such_key unless @data.include?(name)
      @data[name]
    end
  end
end

