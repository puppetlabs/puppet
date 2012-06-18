require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_decorator'

module Puppet
  module DSL
    class Context < BlankSlate

      def initialize(scope, &code)
        @scope = scope
        @compiler = scope.compiler
        @parent = scope.resource
        @code = code
      end

      def evaluate
        instance_eval &@code
      end

      def node(name, options = {}, &block)
        raise ::ArgumentError if block.nil? or not valid_nesting? :node

        node = @compiler.known_resource_types.add ::Puppet::Resource::Type.new(
          :node,
          name#,
          # :parent => @parent
        )

        resource = node.ensure_in_catalog @scope
        resource.evaluate

        ::Puppet::DSL::Context.new(@scope.newscope(:resource => resource), &block).evaluate
      end

      def hostclass(name, options = {}, &block)
        raise ::ArgumentError if block.nil? or not valid_nesting? :hostclass

        hostclass = @compiler.known_resource_types.add ::Puppet::Resource::Type.new(
          :hostclass,
          name#,
          #:parent => parent
        )

        resource = hostclass.ensure_in_catalog @scope
        resource.evaluate

        ::Puppet::DSL::Context.new(@scope.newscope(:resource => resource), &block).evaluate
      end

      def define(name, options = {}, &block)
        puts "definition: #{options.inspect}"
        raise ArgumentError if block.nil? or not valid_nesting? :definition

        definition = @compiler.known_resource_types.add ::Puppet::Resource::Type.new(
          :definition,
          name#,
          #:parent => parent
        )

        resource = definition.ensure_in_catalog @scope
        resource.evaluate

        ::Puppet::DSL::Context.new(@scope.newscope(:resource => resource), &block).evaluate
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
        # MLEN:TODO: implement nesting validation
        true
      end

      def method_missing(name, *args, &block)
        raise "MethodMissing loop when searching for #{name}" if @searching_for_method
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
        raise ::NoMethodError unless valid_type? type
        options = args.last.is_a?(Hash) ? args.pop : {}

        Array(args).map do |name|
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
        raise ::NoMethodError unless valid_function? name
        @scope.send name, args
      end

    end
  end
end

