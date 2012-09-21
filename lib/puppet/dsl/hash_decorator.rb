require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_reference'

module Puppet
  module DSL
    ##
    # Thin decorator layer for accessing attributes of array/hash-like objects.
    # Example usage of this class can be found in
    # Puppet::DSL::Context#create_resource method.
    #
    # This class inherits from BlankSlate
    ##
    class HashDecorator < BlankSlate

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
        if name[-1] == '='
          define_singleton_method name do |*a|
            value = a.first
            value = value.reference if value.is_a? ::Puppet::DSL::ResourceReference
            value = value.to_s  unless value.is_a? ::Puppet::Resource
            @resource[name[0...-1].to_sym] = value
          end

          self.__send__ name, *args
        else
          define_singleton_method name do
            @resource[name]
          end

          self.__send__ name, *args
        end
      end

    end
  end
end

