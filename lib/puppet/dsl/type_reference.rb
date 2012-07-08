require 'puppet/parser/collector'
require 'puppet/parser/resource/param'
require 'puppet/dsl/resource_reference'
require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/parser'
require 'puppet/dsl/helper'

module Puppet
  module DSL
    ##
    # TypeReference object is returned by +Context#const_missing+.
    # It allows to set defaults, create collections and get references for
    # resources of given type.
    ##
    class TypeReference
      include Puppet::DSL::Helper

      ##
      # Creates new TypeReference.
      ##
      def initialize(typename)
        @type = canonize_type typename
        @cache = {}
      end

      ##
      # Returns a ResourceReference.
      # Raises ArgumentError when resource cannot be found.
      # Method caches references for future use.
      ##
      def [](reference)
        return @cache[reference] if @cache[reference]

        unless Puppet::DSL::Parser.current_scope.findresource @type, reference
          raise ArgumentError, "resource `#{@type.capitalize}[#{reference}]' not found"
        else
          @cache[reference] = Puppet::DSL::ResourceReference.new @type, reference
        end
      end

      ##
      # Method creates a collection for exported resources.
      ##
      def collect
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type.capitalize, nil, nil, :exported
        scope.compiler.add_collection c
      end

      ##
      # Method creates a collection for virtual resources.
      ##
      def realise
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type.capitalize, nil, nil, :virtual
        scope.compiler.add_collection c
      end

      ##
      # Method allows to set defaults for a resource type.
      ##
      def defaults(options = {}, &block)
        Puppet::DSL::ResourceDecorator.new(options, &block) unless block.nil?

        # for compatibility with Puppet parser
        options = options.map do |k, v|
          Puppet::Parser::Resource::Param.new :name => k, :value => v
        end
        Puppet::DSL::Parser.current_scope.define_settings @type, options
      end

    end
  end
end

