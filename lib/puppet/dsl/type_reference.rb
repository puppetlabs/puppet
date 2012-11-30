require 'puppet/parser/collector'
require 'puppet/parser/resource/param'
require 'puppet/dsl/resource_reference'
require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/parser'

module Puppet
  # @since 3.1 EXPERIMENTAL
  module DSL
    ##
    # TypeReference object is returned by +Context#const_missing+.
    # It allows to set defaults, create collections and get references for
    # resources of given type.
    ##
    class TypeReference

      ##
      # Returns Puppet type represented by this reference
      ##
      attr_reader :type_name
      alias to_s type_name

      ##
      # Creates new TypeReference.
      # Raises NameError when resource type is not found
      ##
      def initialize(typename)
        name = Puppet::Resource.canonicalize_type typename
        if Puppet::DSL::Context.const_defined? name
          @type_name = name
          @cache = {}
        else
          raise NameError, "resource type `#{name}' not found"
        end
      end

      ##
      # Returns a ResourceReference.
      # Raises ArgumentError when resource cannot be found.
      # Method caches references for future use.
      ##
      def [](reference)
        @cache[reference] ||= Puppet::DSL::ResourceReference.new self, reference
      end

      ##
      # Method creates a collection for exported resources.
      ##
      def collect
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type_name, nil, nil, :exported
        scope.compiler.add_collection c
        c
      end

      ##
      # Method creates a collection for virtual resources.
      ##
      def realize
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type_name, nil, nil, :virtual
        scope.compiler.add_collection c
        c
      end

      ##
      # Method allows to set defaults for a resource type.
      ##
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

