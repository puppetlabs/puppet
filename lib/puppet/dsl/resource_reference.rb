require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/parser'
require 'puppet/parser/resource/param'
require 'puppet/parser/resource'

module Puppet
  # @since 3.1 
  # @status EXPERIMENTAL
  module DSL
    # ResourceReference is a thin wrapper for assigning references to the
    # resources and creating overrides.
    #
    class ResourceReference
      # @return [Puppet::Parser::Resource] referenced resource
      #
      attr_reader :resource

      # Creates a new ResourceReference.
      # @param typeref [String] the name of the type
      # @param name [String] the name of a resource instance of this type
      # @raise [ArgumentError] if the referenced _typename_/_name_ is not found
      #
      def initialize(typeref, name)
        @resource = Puppet::DSL::Parser.current_scope.findresource typeref.type_name, name
        raise ArgumentError, "resource `#{typeref.type_name}[#{name}]' not found" unless @resource
      end

      # This method is used by ResourceDecorator for stringifying references.
      # @return [String] the resource in string form
      #
      def reference
        @resource.to_s
      end
      alias to_s reference

      # Creates overrides for a resource and returns the resulting overrides as a Hash.
      # @overload override(options)
      # @overload override(options, {|r| block}
      # @overload override({|r| block})
      # @param options [Hash] parameter name to value mapping of values to override.
      # @param r [ResourceReference] the `self` when evaluating the Ruby DSL block.
      # @param block [ruby] Ruby DSL statements to be executed.
      # @return [Hash] a hash with a mapping from parameter name to value with overridden name/values.
      # @raise [ArgumentError] when no block or options have been supplied.
      #
      def override(options = {}, &block)
        raise ArgumentError, "no block or options supplied" if options == {} and block.nil?

        Puppet::DSL::ResourceDecorator.new(options, &block) unless block.nil?
        scope = Puppet::DSL::Parser.current_scope

        # for compatibility with Puppet parser
        params = options.map do |k, v|
          Puppet::Parser::Resource::Param.new :name => k, :value => v, :source => scope.source
        end

        resource = Puppet::Parser::Resource.new @resource.type, @resource.name,
                                                :parameters => params, :scope => scope,
                                                :source => scope.source

        override = scope.compiler.add_override resource

        result = {}
        override.each do |_, v|
          result.merge! v.name => v.value
        end
        result
      end

      # Realizes referenced virtual resource.
      # @return [Puppet::Parser::Collector, nil] collector containing the realized resource, or nil if it is not virtual.
      #
      def realize
        return unless @resource.virtual
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type, nil, nil, :virtual
        c.resources = [@resource]
        scope.compiler.add_collection c
        c
      end

      # Collects referenced exported resource
      # @return [Puppet::Parser::Collector, nil] collector containing the collected resource, or nil if it is not exported.
      #
      def collect
        return unless @resource.exported
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type, nil, nil, :exported
        c.resources = [@resource]
        scope.compiler.add_collection c
        c
      end
    end
  end
end
