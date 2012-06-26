require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_decorator'

module Puppet
  module DSL
    class Context < BlankSlate

      Parser = ::Puppet::DSL::Parser

      def initialize(code)
        @code = code
      end

      def evaluate(scope)
        Parser.add_scope scope
        instance_eval &@code
        Parser.remove_scope
        self
      end

      def node(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil?
        ::Kernel.raise ::NoMethodError unless Parser.valid_nesting?

        params = {}
        params.merge! :parent => options[:inherits] if options[:inherits]
        node = ::Puppet::Resource::Type.new :node, name, params
        node.ruby_code = ::Puppet::DSL::Context.new block
        Parser.current_scope.compiler.known_resource_types.add node
      end

      def hostclass(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil?
        ::Kernel.raise ::NoMethodError unless Parser.valid_nesting?

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        params.merge! :parent => options[:inherits] if options[:inherits]

        hostclass = ::Puppet::Resource::Type.new :hostclass, name, params
        hostclass.ruby_code = ::Puppet::DSL::Context.new block

        Parser.current_scope.compiler.known_resource_types.add hostclass
      end

      def define(name, options = {}, &block)
        ::Kernel.raise ::ArgumentError if block.nil?
        ::Kernel.raise ::NoMethodError unless Parser.valid_nesting?

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        definition = ::Puppet::Resource::Type.new :definition, name, params
        definition.ruby_code = ::Puppet::DSL::Context.new block
        Parser.current_scope.compiler.known_resource_types.add definition
      end

      def use(*args)
        create_resource :class, *args
      end

      def valid_type?(name)
        !!([:node, :class].include? name or
           ::Puppet::Type.type name or
           Parser.current_scope.compiler.known_resource_types.definition name)
      end

      def valid_function?(name)
        !!::Puppet::Parser::Functions.function(name)
      end

      def respond_to?(name)
        valid_type? name or valid_function? name
      end

      def method_missing(name, *args, &block)
        if valid_type? name
          create_resource name, *args, &block
        elsif valid_function? name
          call_function name, *args
        else
          super
        end
      end

      def params
        Parser.current_scope
      end

      def create_resource(type, *args, &block)
        ::Kernel.raise ::NoMethodError unless valid_type? type
        options = args.last.is_a?(::Hash) ? args.pop : {}
        scope = Parser.current_scope

        ::Kernel::Array(args).map do |name|
          resource = ::Puppet::Parser::Resource.new type, name, :scope => scope, :source => scope.source
          options[:virtual] = true if virtualizing?
          options[:exported] = true if exporting?
          options.each do |key, val|
            resource[key] = val
          end

          ::Puppet::DSL::ResourceDecorator.new(resource, &block) if block

          scope.compiler.add_resource scope, resource
          resource
        end
      end

      # Calls a puppet function
      def call_function(name, *args)
        ::Kernel.raise ::NoMethodError unless valid_function? name
        Parser.current_scope.send name, args
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

