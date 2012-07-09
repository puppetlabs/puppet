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
      def initialize(type, name)
        @resource = Puppet::DSL::Parser.current_scope.compiler.findresource type, name
      end

      ##
      # This method is used by ResourceDecorator for stringifying references.
      ##
      def to_s
        @resource.to_s
      end

      ##
      # Method allows to create overrides for a resource.
      ##
      def override(options = {}, &block)
        Puppet::DSL::ResourceDecorator.new(options, &block) unless block.nil?
        scope = Puppet::DSL::Parser.current_scope

        # for compatibility with Puppet parser
        params = options.map do |k, v|
          Puppet::Parser::Resource::Param.new :name => k, :value => v, :source => scope.source
        end

        resource = Puppet::Parser::Resource.new @resource.type, @resource.name,
                                                :parameters => params, :scope => scope,
                                                :source => scope.source
        scope.compiler.add_override resource
      end
    end
  end
end

