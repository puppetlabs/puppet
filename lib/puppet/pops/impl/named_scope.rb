require 'puppet/pops/api'
require 'puppet/pops/impl'
require 'puppet/pops/impl/base_scope'

module Puppet::Pops::Impl
  class NamedScope < BaseScope
    attr_reader :scope_name
    def initialize(scope_name)
      super()
      # TODO: Check scope name's validity
      @scope_name = scope_name.to_s.dup.freeze  # or kill a unicorn
    end

    def is_named_scope?
      true
    end

    def set_data(type, name, value, origin = nil)
      parent_scope.set_data(type, name, value, origin)
    end

    def set_variable(name, value, origin = nil)
      parent_scope.set_variable([scope_name, "::", name].join(), value, origin)
    end

    def get_variable_entry(name)
      # absolute name
      return parent_scope.get_variable_entry(name) if Utils.is_absolute?(name)
      if entry = parent_scope.get_variable_entry([scope_name, "::", name].join())
        # name in this context
        entry
      else
        # or in global
        parent_scope.get_variable_entry(["::", name].join())
      end
    end

    def get_data_entry(type, name)
      parent_scope.get_data_entry(type, name)
    end
  end
end
