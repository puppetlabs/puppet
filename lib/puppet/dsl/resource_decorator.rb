require 'puppet/dsl/blank_slate'

module Puppet
  module DSL
    ##
    # Thin decorator layer for accessing attributes of array/hash-like objects.
    # Example usage of this class can be found in
    # Puppet::DSL::Context#create_resource method.
    #
    # This class inherits from BlankSlate
    ##
    class ResourceDecorator < BlankSlate

      ##
      # Regular expression used when determining whether method is a setter.
      ##
      SETTER_REGEX = /\A(.*)=\z/

      ##
      # Initializes new object.
      # +resource+ can be any object that responds to +[]+ and +[]=+ methods.
      # +block+ can be any kind of object that responds to +call+ methods.
      ##
      def initialize(resource, &block)
        @resource = resource
        block.call self
      end

      ##
      # It is a proxy method that allows to access resource parameters using
      # methods +[]+ and +[]=+.
      #
      # After a first call it creates a cached version of a method.
      #
      # Example:
      #
      #   # use this
      #   r.title = "I am a resource"
      #   # instead of this
      #   r[:title] = "I am a resource"
      #
      ##
      def method_missing(name, *args)
        raise "loop for #{name}" if @searching
        @searching = true
        super unless respond_to? name
        if name =~ SETTER_REGEX
          define_singleton_method name do |*a|
            @resource[$1.to_sym] = a.first.to_s
          end

          @resource[$1.to_sym] = args.first.to_s
        else
          define_singleton_method name do
            @resource[name]
          end

          @resource[name]
        end
      ensure
        @searching = false
      end

      ##
      # Checks whether it can respond to a method call.
      # It validates parameter names for a Puppet::Resource.
      # For other classes it always returns true.
      ##
      def respond_to?(name)
        if @resource.is_a? ::Puppet::Resource
          name = $1.to_sym if name =~ SETTER_REGEX
          @resource.valid_parameter? name
        else
          true
        end
      end
    end
  end
end

