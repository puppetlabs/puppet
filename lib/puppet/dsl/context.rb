require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_decorator'

module Puppet
  module DSL
    class Context < BlankSlate

      def initialize(code, nesting = 0)
        @code = code
        @nesting = nesting
      end

      def evaluate(scope)
        @scope = scope
        @compiler = scope.compiler
        instance_eval &@code
        self
      end

      def node(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil?
        ::Kernel.raise ::NoMethodError unless valid_nesting?

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        params.merge! :parent => options[:inherits] if options[:inherits]
        node = ::Puppet::Resource::Type.new :node, name, params
        node.ruby_code = ::Puppet::DSL::Context.new block, @nesting + 1
        @compiler.known_resource_types.add node
      end

      def hostclass(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil?
        ::Kernel.raise ::NoMethodError unless valid_nesting?

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        params.merge! :parent => options[:inherits] if options[:inherits]

        hostclass = ::Puppet::Resource::Type.new :hostclass, name, params
        hostclass.ruby_code = ::Puppet::DSL::Context.new block, @nesting + 1
        @compiler.known_resource_types.add hostclass
      end

      def define(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil?
        ::Kernel.raise ::NoMethodError unless valid_nesting?

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        definition = ::Puppet::Resource::Type.new :definition, name, params
        definition.ruby_code = ::Puppet::DSL::Context.new block, @nesting + 1
        @compiler.known_resource_types.add definition
      end

      def valid_type?(name)
        !!([:node, :class].include? name or
           ::Puppet::Type.type name or
           @compiler.known_resource_types.definition name)
      end

      def valid_function?(name)
        !!::Puppet::Parser::Functions.function(name)
      end

      def valid_nesting?
        @nesting == 0
      end

      def respond_to?(name)
        valid_type? name or valid_function? name
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
          options[:virtual] = true if virtualizing?
          options[:exported] = true if exporting?
          options.each do |key, val|
            resource[key] = val
          end

          ::Puppet::DSL::ResourceDecorator.new(resource, &block) if block

          @compiler.add_resource @scope, resource
          resource
        end
      end

      # Calls a puppet function
      def call_function(name, *args)
        ::Kernel.raise ::NoMethodError unless valid_function? name
        @scope.send name, args
      end

      def exporting?
        @exporting
      end

      def virtualizing?
        @virtualizing
      end

      def export(*args, &block)
        unless block
          begin
            @exporting = true
            instance_eval &block
          ensure
            @exporting = false
          end
        else
          args.each { |r| r[:exported] = true }
        end
      end

      def virtualize(*args, &block)
        unless block
          begin
            @virtualizing = true
            instance_eval &block
          ensure
            @virtualizing = false
          end
        else
          args.each { |r| r[:virtual] = true }
        end
      end

    end
  end
end

