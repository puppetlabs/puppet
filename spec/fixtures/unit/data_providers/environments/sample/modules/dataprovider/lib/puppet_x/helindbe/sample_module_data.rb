# The module is named after the author, to ensure that names under PuppetX namespace
# does not clash.
#
require 'puppet_x'
module PuppetX::Helindbe

  # A module data provider that is hardcoded and provides data for
  # the three names 'test::param_a', 'test::param_b', and 'test::param_c'
  #
  # A real implementation would read the data from somewhere or invoke some
  # other service to obtain the data. When doing so caching may be performance
  # critical, and it is important that a cache is associated with the apropriate
  # object to not cause memory leaks. See more details in the documentation
  # for how to write a data provider and use adapters.
  #
  class SampleModuleData < Puppet::Plugins::DataProviders::ModuleDataProvider
    def initialize()
      @data = { 
        'dataprovider::test::param_a' => 'module data param_a is 100',
        'dataprovider::test::param_b' => 'module data param_b is 200',

        # demo: uncomment the entry below to make it override the environment provided data
        #'dataprovider::test::param_c' => 'env data param_c is 300',
      }
    end

    def lookup(name, scope, merge)
      throw :no_such_key unless @data.include?(name)
      @data[name]
    end
  end
end

