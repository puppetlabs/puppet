module Puppet
  module DSL

    ##
    # BlankSlate is a class intended for use with +method_missing+.
    # Ruby 1.9 version is based on BasicObject.
    # Ruby 1.8 version has almost all methods undefined.
    #
    # Ruby 1.9 version doesn't include Kernel module.
    # To reference a constant in that version +::+ has to be prepended to
    # constant name.
    ##
    if RUBY_VERSION < "1.9"
      ##
      # Ruby 1.8 version
      ##
      class BlankSlate
        ##
        # Undefine all methods but those defined in BasicObject.
        ##
        instance_methods.each do |m|
          unless [:==, :equal?, :'!', :'!=', :instance_eval, :instance_exec,
                  :__send__, :__id__].include? m
            undef_method m
          end
        end
      end
    else
      ##
      # Ruby 1.9 version
      ##
      class BlankSlate < BasicObject; end
    end

    # :nodoc: Needs to be required here to avoid circular dependencies
    require 'puppet/dsl/type_reference'
    require 'puppet/dsl/helper'

    ##
    # Reopening class to add methods.
    ##
    class BlankSlate
      include ::Puppet::DSL::Helper

      ##
      # Proxy method for Kernel#raise
      ##
      def raise(*args)
        ::Object.send :raise, *args
      end

      ##
      # Provides syntactic sugar for resource references.
      # It checks whether a constant exists and returns TypeReference
      # corresponding to that constant. Otherwise it raises NameError.
      # A cached version of TypeReference is created on the first call.
      #
      # For further information look at lib/puppet/dsl/type_reference.rb
      ##
      def self.const_missing(name)
        if self.const_defined? name
          ref = ::Puppet::DSL::TypeReference.new name.downcase
          self.const_set name, ref
          ref
        else
          raise ::NameError, "resource type `#{name}' not found"
        end
      end

      ##
      # Returns whether a constant is defined.
      # It essentially checks if the type exists.
      # The algorithm is identical to one used in +respond_to?+ method.
      ##
      def self.const_defined?(name)
        type = name.downcase
        super || !!([:node, :class].include? type or
           ::Puppet::Type.type type or
           ::Puppet::DSL::Parser.current_scope.compiler.known_resource_types.definition type
          )
      end

      ##
      # Returns type reference. A fallback method for obtaining type references
      # for Ruby 1.8 users.
      ##
      def type(name)
        if ::Puppet::DSL::Context.const_defined? canonize_type(name)
          ::Puppet::DSL::TypeReference.new name.downcase
        else
          raise ::NameError, "resource type `#{name}' not found"
        end
      end

      ##
      # Redefine method from Object, as BasicObject doesn't include it.
      # It is used to define a singleton method on Context to cache
      # +method_missing+ calls.
      ##
      private
      def define_singleton_method(name, &block)
        class << self; self; end.instance_eval do
          define_method name, &block
        end
      end
    end

  end
end

