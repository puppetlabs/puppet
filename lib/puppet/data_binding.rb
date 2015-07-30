require 'puppet/indirector'

# A class for managing data lookups
class Puppet::DataBinding
  # Set up indirection, so that data can be looked for in the compiler
  extend Puppet::Indirector

  indirects(:data_binding, :terminus_setting => :data_binding_terminus,
    :doc => "Where to find external data bindings.")

  class LookupError < Puppet::Error; end

  class RecursiveLookup < Puppet::DataBinding::LookupError; end

  class LookupInvocation
    attr_reader :scope, :override_values, :default_values

    # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
    # @param override_values [Hash<String,Object>|nil] A map to use as override. Values found here are returned immediately (no merge)
    # @param default_values [Hash<String,Object>] A map to use as the last resort (but before default)
    def initialize(scope, override_values = {}, default_values = {})
      @name_stack = []
      @scope = scope
      @override_values = override_values
      @default_values = default_values
    end

    def check(name)
      raise RecursiveLookup, "Detected in [#{@seen.join(', ')}]" if @name_stack.include?(name)
      return unless block_given?

      @name_stack.push(name)
      begin
        yield
      rescue LookupError
        raise
      rescue Puppet::Error => detail
        raise LookupError.new(detail.message, detail)
      ensure
        @name_stack.pop
      end
    end
  end
end
