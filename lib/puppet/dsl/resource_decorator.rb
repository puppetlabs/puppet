require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_reference'

module Puppet
  # @since 3.1 
  # @status EXPERIMENTAL
  module DSL
    # Thin decorator layer for accessing attributes of array/hash-like objects.
    # @see Puppet::DSL::Context#create_resource  Context#create_resource for examples of usage
    #
    class ResourceDecorator < BlankSlate

      # Initializes new object.
      # @overload initialize(resource, {|r| block})
      # @param resource [#[], #[]=] any object responding to these methods
      # @yieldparam r [ResourceDecorator] the `self` when evaluating the ruby block
      # @param block [ruby] the Ruby DSL statements to evaluate.
      #
      def initialize(resource, &block)
        @resource = resource
        block.call self
      end

      # A proxy method allowing direct access to resource parameters instead of
      # having to use `#[]` or `#[]=`
      #
      # After a first call it creates a cached version of the created access method.
      #
      # @example
      #   # allows using this
      #   r.title = "I am a resource"
      #   # instead of this
      #   r[:title] = "I am a resource"
      #
      def method_missing(name, *args)
        if name.to_s =~ /\A(.*)=\z/
          define_singleton_method name do |*a|
            value = a.first
            value = value.reference if value.is_a? ::Puppet::DSL::ResourceReference
            value = value.to_s  unless value.is_a? ::Puppet::Resource
            @resource[$1.to_sym] = value
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
