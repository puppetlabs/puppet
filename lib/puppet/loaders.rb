require 'puppet/concurrent/synchronized'

module Puppet
  module Pops
    require 'puppet/pops/loaders'

    module Loader
      require 'puppet/pops/loader/typed_name'
      require 'puppet/pops/loader/loader'
      require 'puppet/pops/loader/base_loader'
      require 'puppet/pops/loader/gem_support'
      require 'puppet/pops/loader/module_loaders'
      require 'puppet/pops/loader/dependency_loader'
      require 'puppet/pops/loader/static_loader'
      require 'puppet/pops/loader/runtime3_type_loader'
      require 'puppet/pops/loader/ruby_function_instantiator'
      require 'puppet/pops/loader/ruby_legacy_function_instantiator'
      require 'puppet/pops/loader/ruby_data_type_instantiator'
      require 'puppet/pops/loader/puppet_function_instantiator'
      require 'puppet/pops/loader/type_definition_instantiator'
      require 'puppet/pops/loader/puppet_resource_type_impl_instantiator'
      require 'puppet/pops/loader/loader_paths'
      require 'puppet/pops/loader/simple_environment_loader'
      require 'puppet/pops/loader/predefined_loader'
      require 'puppet/pops/loader/generic_plan_instantiator'
      require 'puppet/pops/loader/puppet_plan_instantiator'

      # The implementation of synchronized applies it to all subclasses so we
      # want to add it to be base class after any subclasses are created
      Loader.include Puppet::Concurrent::Synchronized
    end
  end

end
