require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/parser'
require 'puppet/parser/resource/param'
require 'puppet/parser/resource'

module Puppet
  module DSL
    ##
    # ResourceReference is a thin wrapper for assigning references to the
    # resources and creating overrides.
    ##
    class ResourceReference
      ##
      # Returns referenced resource
      ##
      attr_reader :resource

      ##
      # Creates new ResourceReference.
      # +type+ is the name of resource type and +name+ is a name of a resource.
      ##
      def initialize(typeref, name)
        @resource = Puppet::DSL::Parser.current_scope.findresource typeref.type, name
        raise ArgumentError, "resource `#{typeref.type}[#{name}]' not found" unless @resource
      end

      ##
      # This method is used by ResourceDecorator for stringifying references.
      ##
      def reference
        @resource.to_s
      end
      alias to_s reference

      ##
      # Method allows to create overrides for a resource.
      ##
      def override(options = {}, &block)
        raise ArgumentError if options == {} and block.nil?

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

      ##
      # Realizes referenced resource
      ##
      def realize
        return unless @resource.virtual
        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type, nil, nil, :virtual
        c.resources = [@resource]
        scope.compiler.add_collection c
        c
      end

      ##
      # Collects referenced resource
      ##
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

