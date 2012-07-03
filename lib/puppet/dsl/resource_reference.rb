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
      #
      # MLEN:FIXME: Not yet implemented.
      ##
      def override(options = {}, &block)
        raise NotImplementedError
      end
    end
  end
end

