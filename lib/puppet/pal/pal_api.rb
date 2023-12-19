# frozen_string_literal: true

module Puppet
  require_relative '../../puppet/parser/script_compiler'
  require_relative '../../puppet/parser/catalog_compiler'

  module Pal
    require_relative '../../puppet/pal/json_catalog_encoder'
    require_relative '../../puppet/pal/function_signature'
    require_relative '../../puppet/pal/task_signature'
    require_relative '../../puppet/pal/plan_signature'
    require_relative '../../puppet/pal/compiler'
    require_relative '../../puppet/pal/script_compiler'
    require_relative '../../puppet/pal/catalog_compiler'
    require_relative '../../puppet/pal/pal_impl'
  end
end
