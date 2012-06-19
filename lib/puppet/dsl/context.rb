require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_decorator'

module Puppet
  module DSL
    class Context #< BasicObject

      def initialize(scope, code)
        @scope = scope
        @compiler = scope.compiler
        @code = code
      end

      def evaluate
        instance_eval &@code
      end

      def node(name, options = {}, &block)
        raise ::ArgumentError if block.nil? or not valid_nesting? :node

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        params.merge! :parent => options[:inherits] if options[:inherits]
        node = @compiler.known_resource_types.find_node nil, name
        node ||= @compiler.known_resource_types.add ::Puppet::Resource::Type.new(
          :node,
          name,
          params
        )

        resource = node.ensure_in_catalog @scope
        resource.evaluate

        ::Puppet::DSL::Context.new(@scope.newscope(:resource => resource), block).evaluate
      end

      def hostclass(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil? or not valid_nesting? :hostclass

        args = options[:arguments] || {}
        hostclass = @compiler.known_resource_types.add ::Puppet::Resource::Type.new(
          :hostclass,
          name,
          :arguments => args
        )
        hostclass.ruby_code = ::Puppet::DSL::Context.new(@scope.compiler.newscope(nil), block)
      end

      def define(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil? or not valid_nesting? :definition

        args = options[:arguments] || {}
        definition = @compiler.known_resource_types.add ::Puppet::Resource::Type.new(
          :definition,
          name,
          :arguments => args
        )

        resource = definition.ensure_in_catalog @scope
        resource.evaluate

        ::Puppet::DSL::Context.new(@scope.newscope(:resource => resource), block).evaluate
      end

      def valid_type?(name)
        !!([:node, :class].include? name or
           ::Puppet::Type.type name or
           @compiler.known_resource_types.definition name)
      end

      def valid_function?(name)
        !!::Puppet::Parser::Functions.function(name)
      end

      def valid_nesting?(type)
        # MLEN:TODO implement nesting validation
        true
      end

      def method_missing(name, *args, &block)
        ::Kernel.raise "MethodMissing loop when searching for #{name}" if @searching_for_method
        @searching_for_method = true

        if valid_type? name
          create_resource name, *args, &block
        elsif valid_function? name
          call_function name, *args
        else
          super
        end
      ensure
        @searching_for_method = false
      end

      def params
        @scope
      end

      def create_resource(type, *args, &block)
        ::Kernel.raise ::NoMethodError unless valid_type? type
        options = args.last.is_a?(::Hash) ? args.pop : {}

        ::Kernel::Array(args).map do |name|
          resource = ::Puppet::Parser::Resource.new type, name, :scope => @scope
          options.each do |key, val|
            resource[key] = val
          end

          ::Puppet::DSL::ResourceDecorator.new(resource, block) if block

          @compiler.add_resource @scope, resource
          resource
        end
      end

      # Calls a puppet function
      def call_function(name, *args)
        ::Kernel.raise ::NoMethodError unless valid_function? name
        @scope.send name, args
      end

    end
  end
end

