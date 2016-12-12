# The module is named after the author, to ensure that names under PuppetX namespace
# does not clash.
#
require 'puppet_x'

module PuppetX::Thallgren
  class SampleModuleData < Puppet::Plugins::DataProviders::ModuleDataProvider
    def initialize()
      @data = {
        'metawcp::b' => 'module_b',
        'metawcp::c' => 'module_c',
        'metawcp::e' => { 'k1' => 'module_e1', 'k2' => 'module_e2' },
        'metawcp::f' => { 'k1' => { 's1' => 'module_f11', 's3' => 'module_f13' },  'k2' => { 's1' => 'module_f21', 's2' => 'module_f22' }},
      }
    end

    def lookup(name, scope, merge)
      throw :no_such_key unless @data.include?(name)
      @data[name]
    end
  end
end

