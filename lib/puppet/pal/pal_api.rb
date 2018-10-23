module Puppet
  require 'puppet/parser/script_compiler'
  require 'puppet/parser/catalog_compiler'

  module Pal
    require 'puppet/pal/json_catalog_encoder'
    require 'puppet/pal/function_signature'
    require 'puppet/pal/task_signature'
    require 'puppet/pal/plan_signature'
    require 'puppet/pal/compiler'
    require 'puppet/pal/script_compiler'
    require 'puppet/pal/catalog_compiler'
    require 'puppet/pal/pal_impl'
  end
end
