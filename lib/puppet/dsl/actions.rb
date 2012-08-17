require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/scope_decorator'
require 'puppet/dsl/type_reference'
require 'puppet/dsl/helper'

module Puppet
  module DSL

    # Error type used by Ruby DSL when resource type doesn't exist
    class InvalidTypeError < Puppet::Error; end

    # Error type used by Ruby DSL when Puppet function doesn't exist
    class InvalidFunctionError < Puppet::Error; end

    ##
    # This class is created for ease of debugging.
    # Unlike Puppet::DSL::Context it inherits from Object and works fine with
    # pry, a very useful debugging tool.
    # Puppet::DSL::Context forwards all the calls to a proxy instance.
    # This also allows to limit the number of methods existing in that class.
    ##
    class Actions
      include Puppet::DSL::Helper

      ##
      # Initializes a Proxy instance.
      # The filename argument is only used when creating new nodes, definitions
      # or classes.
      ##
      def initialize(filename)
        @filename     = filename
        @exporting    = false
        @virtualizing = false
      end

      ##
      # Returns type reference of a given type.
      # It expects to be called with a type name string.
      ##
      def type_reference(name)
        TypeReference.new name
      end

      ##
      # Checks whether resource type exists
      ##
      def is_resource_type?(name)
        type = canonize_type(name)
        !!(["Node", "Class"].include? type or
           Puppet::Type.type type or
           Parser.current_scope.known_resource_types.find_definition '', type or
           Parser.current_scope.known_resource_types.find_hostclass  '', type)
      end

      ##
      # Checks whether Puppet function exists
      ##
      def is_function?(name)
        !!Puppet::Parser::Functions.function(name)
      end

      ##
      # Returns object for accessing params hash
      # All keys will be stringified
      ##
      def params
        ScopeDecorator.new Parser.current_scope
      end

      ##
      # Creates a new Puppet node. All arguments have to be passed.
      # Nesting is the nesting of scopes in the Ruby DSL,
      # Code is a Ruby block of code for that node,
      # Options is a hash of options passed when declaring a node,
      # Name is the name of created node.
      ##
      def create_node(name, options, code, nesting)
        raise NoMethodError, "called from invalid nesting" if nesting > 0
        raise ArgumentError, "no block supplied"           if code.nil?

        options.each do |k, _|
          unless :inherits == k
            raise ArgumentError, "unrecognized option #{k} in node #{name}"
          end
        end

        params = {}
        if options[:inherits]
          options[:inherits] = options[:inherits].to_s unless options[:inherits].is_a? Regexp
          params[:parent] = options[:inherits]
        end

        name = name.to_s unless name.is_a? Regexp
        node = Puppet::Resource::Type.new :node, name, params
        node.ruby_code = Context.new code, :filename => @filename, :nesting => nesting + 1

        Parser.current_scope.known_resource_types.add_node node
      end

      ##
      # Creates a new hostclass. All arguments are required.
      # Nesting is the nesting of scopes in the Ruby DSL,
      # Code is a ruby block passed when calling hostclass method in DSL,
      # Options is a has of settings for a hostclass,
      # Name is the name for the new hostclass.
      ##
      def create_hostclass(name, options, code, nesting)
        raise NoMethodError, "called from invalid nesting" if nesting > 0
        raise ArgumentError, "no block supplied"           if code.nil?

        options.each do |k, _|
          unless [:arguments, :inherits].include? k
            raise ArgumentError, "unrecognized option #{k} in hostclass #{name}"
          end
        end

        params = {}
        params[:arguments] = options[:arguments]     if options[:arguments]
        params[:parent]    = options[:inherits].to_s if options[:inherits]

        hostclass = Puppet::Resource::Type.new :hostclass, name.to_s, params
        hostclass.ruby_code = Context.new code, :filename => @filename, :nesting => nesting + 1

        Parser.current_scope.known_resource_types.add_hostclass hostclass
      end

      ##
      # Creates new definition. All arguments are required.
      # Nesting is the nesting of scopes in Ruby DSL,
      # Code is a ruby block passed to the DSL method,
      # Options is a hash of arguments for the definition,
      # Name is the name for the new definition.
      ##
      def create_definition(name, options, code, nesting)
        raise NoMethodError, "called from invalid nesting" if nesting > 0
        raise ArgumentError, "no block supplied"           if code.nil?

        options.each do |k, _|
          unless :arguments == k
            raise ArgumentError, "unrecognized option #{k} in definition #{name}"
          end
        end

        params = {}
        params[:arguments] = options[:arguments] if options[:arguments]
        definition = Puppet::Resource::Type.new :definition, name.to_s, params
        definition.ruby_code = Context.new code, :filename => @filename, :nesting => nesting + 1

        Parser.current_scope.known_resource_types.add_definition definition
      end

      ##
      # Creates a definition, all arguments are required.
      # Type is a Puppet Type of a resource,
      # Args can be an Array or a single object containing name of a resource,
      # Options is a hash of parameters for that resource,
      # Code is a proc that will set additional parameters, can be nil.
      ##
      def create_resource(type, args, options, code)
        # when performing type import the scope is nil
        raise NoMethodError, "resources can't be created in top level scope when importing a manifest" if Parser.current_scope.nil?
        raise Puppet::DSL::InvalidTypeError, "resource type #{type} not found" unless is_resource_type? type

        ResourceDecorator.new(options, &code) if code

        Array(args).map do |name|
          ##
          # Implementation based on
          # lib/puppet/parser/functions/create_resources.rb
          ##
          name  = name.to_s
          scope = Parser.current_scope

          case type
          when :class
            klass = scope.known_resource_types.find_hostclass '', name
            resource = klass.ensure_in_catalog scope, options
          else
            resource = Puppet::Parser::Resource.new type, name,
              :scope => scope,
              :source => scope.source
            options.each do |key, val|
              resource[key] = get_resource(val) || val.to_s
            end

            resource.virtual  = true if virtualizing? or options[:virtual] == true
            resource.exported = true if exporting?    or options[:export]  == true

            definition = scope.known_resource_types.definition name
            definition.instantiate_resource scope, resource if definition

            scope.compiler.add_resource scope, resource
          end
          resource
        end
      end

      ##
      # Calls a puppet function. It behaves exactly the same way as
      # call_function method in Puppet::DSL::Context with one exception: args
      # must be an array.
      ##
      def call_function(name, args)
        # when performing type import the scope is nil
        raise NoMethodError, "resources can't be created in top level scope when importing a manifest" if Parser.current_scope.nil?
        raise Puppet::DSL::InvalidFunctionError, "calling undefined function #{name}(#{args.join ', '})" unless is_function? name
        Parser.current_scope.send name, args
      end

      ##
      # Accessors for changing the exporting/virtualizing state
      ##
      attr_accessor :exporting, :virtualizing

      ##
      # Predicate accessor for :exporting
      ##
      def exporting?
        !!@exporting
      end

      ##
      # Predicate accessor for :virtualizing
      ##
      def virtualizing?
        !!@virtualizing
      end

    end
  end
end

