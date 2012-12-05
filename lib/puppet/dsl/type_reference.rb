require 'puppet/parser/collector'
require 'puppet/parser/resource/param'
require 'puppet/dsl/resource_reference'
require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/parser'

module Puppet
  # @since 3.1 
  # @status EXPERIMENTAL
  module DSL

    # TypeReference object is returned by `Context#const_missing`.
    # It allows to set defaults, create collections and get references for
    # resources of given type.
    #
    class TypeReference

      # @return [String] Puppet type represented by this reference
      #
      attr_reader :type_name
      alias to_s type_name

      # Creates new TypeReference of the given _typename_ type.
      # @param typename [String] the name of the type to create a reference to.
      # @raise [NameError] when resource type is not found
      #
      def initialize(typename)
        name = Puppet::Resource.canonicalize_type typename
        if Puppet::DSL::Context.const_defined? name
          @type_name = name
          @cache = {}
        else
          raise NameError, "resource type `#{name}' not found"
        end
      end

      # Produces a reference to a resource identified by the given _reference_.
      # The result is cached for future use.
      # @return [ResourceReference] reference to resource identified by the given _reference_
      # @raise [ArgumentError] when resource cannot be found.
      #
      def [](reference)
        @cache[reference] ||= Puppet::DSL::ResourceReference.new self, reference
      end

      # Creates a collection for exported resources.
      # @return [Puppet::Parser::Collector] for exported instances of this type reference's type.
      #
      def collect
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type_name, nil, nil, :exported
        scope.compiler.add_collection c
        c
      end

      # Creates a collection for virtual resources.
      # @return [Puppet::Parser::Collector] for virtual instances of this type reference's type.
      #
      def realize
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type_name, nil, nil, :virtual
        scope.compiler.add_collection c
        c
      end

      # Sets and/or gets defaults for the resource type this type reference represents. The values
      # returned are the defaults in effect after the operation.
      # @overload defaults()
      #   @return [Hash] a parameter to value mapping of the current set of defaults.
      #
      # @overload defaults(options)
      #   Sets the defaults in the given options hash as new default values. Only changes
      #   values for the given keys.
      #   @param options [Hash] mapping from parameter name to value of new defaults to set.
      #
      # @overload defaults(options, {|r| block})
      #   @param options [Hash] a parameter to value mapping of the new defaults to set.
      #   @param r [ResourceDecorator] the `self` when evaluating the Ruby DSL block.
      #   @param block [ruby] a block in which Ruby DSL statements can be executed for the resource type.
      # @return [Hash] mapping from parameter name to value of the resulting set of defaults.
      #
      def defaults(options = {}, &block)
        if options != {} or block
          Puppet::DSL::ResourceDecorator.new(options, &block) unless block.nil?

          # for compatibility with Puppet parser
          options = options.map do |k, v|
            Puppet::Parser::Resource::Param.new :name => k, :value => v
          end
          Puppet::DSL::Parser.current_scope.define_settings @type_name, options
        end

        result = {}
        Puppet::DSL::Parser.current_scope.lookupdefaults(@type_name).map do |_, v|
          result[v.name] = v.value
        end
        result
      end

    end
  end
end
