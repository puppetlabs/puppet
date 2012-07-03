module Puppet
  module DSL
    ##
    # ResourceReference is a thin wrapper for assigning references to the
    # resources and creating overrides.
    ##
    class ResourceReference

      ##
      # Creates new ResourceReference.
      # +type+ is the name of resource type and +name+ is a name of a resource.
      ##
      def initialize(type, name)
        @type = type
        @name = name
      end

      ##
      # This method is used by ResourceDecorator for stringifying references.
      ##
      def to_s
        "#{@type.capitalize}[#{@name}]"
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

