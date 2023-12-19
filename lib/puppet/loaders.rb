# frozen_string_literal: true

require_relative '../puppet/concurrent/synchronized'

module Puppet
  module Pops
    require_relative '../puppet/pops/loaders'

    module Loader
      require_relative '../puppet/pops/loader/typed_name'
      require_relative '../puppet/pops/loader/loader'
      require_relative '../puppet/pops/loader/base_loader'
      require_relative '../puppet/pops/loader/gem_support'
      require_relative '../puppet/pops/loader/module_loaders'
      require_relative '../puppet/pops/loader/dependency_loader'
      require_relative '../puppet/pops/loader/static_loader'
      require_relative '../puppet/pops/loader/runtime3_type_loader'
      require_relative '../puppet/pops/loader/ruby_function_instantiator'
      require_relative '../puppet/pops/loader/ruby_legacy_function_instantiator'
      require_relative '../puppet/pops/loader/ruby_data_type_instantiator'
      require_relative '../puppet/pops/loader/puppet_function_instantiator'
      require_relative '../puppet/pops/loader/type_definition_instantiator'
      require_relative '../puppet/pops/loader/puppet_resource_type_impl_instantiator'
      require_relative '../puppet/pops/loader/loader_paths'
      require_relative '../puppet/pops/loader/simple_environment_loader'
      require_relative '../puppet/pops/loader/predefined_loader'
      require_relative '../puppet/pops/loader/generic_plan_instantiator'
      require_relative '../puppet/pops/loader/puppet_plan_instantiator'
    end
  end
end
