require 'puppet/dsl/hash_decorator'
require 'puppet/dsl/type_reference'
require 'puppet/util/methodhelper'

module Puppet
  module DSL

    ##
    # This class is created for ease of debugging.
    # Unlike Puppet::DSL::Context it inherits from Object and works fine with
    # pry, a very useful debugging tool.
    # Puppet::DSL::Context forwards all the calls to Actions instance.
    # This also allows to limit the number of methods existing in that class.
    ##
    class Actions
      include Puppet::Util::MethodHelper

      ##
      # Initializes Puppet::DSL::Actions instance.
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
        type = Puppet::Resource.canonicalize_type(name)
        !!(["Node", "Class"].include? type or
           Puppet::Type.type type or
           Parser.known_resource_types.find_definition '', type or
           Parser.known_resource_types.find_hostclass  '', type)
      end

      ##
      # Checks whether Puppet function exists
      ##
      def is_function?(name)
        # Mangle method name for puppet internals
        name = name.to_s[9..-1] if name.to_s[0...9] == "function_"
        !!Puppet::Parser::Functions.function(name)
      end

      ##
      # Returns object for accessing params hash
      # All keys will be stringified
      ##
      def params
        Parser.current_scope
      end

      ##
      # Creates a new Puppet node. All arguments have to be passed.
      # Nesting is the number of nested blocks in Ruby DSL (this can be
      # basically 0 or 1). Nodes can be only created on the top level scope
      # Options is a hash with parameters provided for the node.
      # Code is a ruby block that will be evaluated as the body of the node
      ##
      def create_node(name, options, nesting, &code)
        raise Puppet::Error, "nodes can be only created in top level scope" if nesting > 0
        raise ArgumentError, "no block supplied" if code.nil?

        validate_options [:inherits], options

        name = name.to_s unless name.is_a? Regexp
        node = Puppet::Resource::Type.new :node, name, :parent => options[:inherits].to_s
        node.ruby_code << Context.new(code, :filename => @filename, :nesting => nesting + 1)

        Parser.known_resource_types.add_node node
      end

      ##
      # Creates a new hostclass. All arguments are required.
      # Nesting is the number of nested blocks in Ruby DSL (this can be
      # basically 0 or 1). Classes can be only created on the top level scope.
      # Options is a hash with parameters provided for the node.
      # Code is a ruby block that will be evaluated as the body of the node.
      ##
      def create_hostclass(name, options, nesting, &code)
        raise Puppet::Error, "classes can be only created in top level scope" if nesting > 0
        raise ArgumentError, "no block supplied" if code.nil?

        validate_options [:inherits, :arguments], options

        hostclass = Puppet::Resource::Type.new :hostclass, name.to_s, :arguments => options[:arguments], :parent => options[:inherits].to_s
        hostclass.ruby_code << Context.new(code, :filename => @filename, :nesting => nesting + 1)

        Parser.known_resource_types.add_hostclass hostclass
      end

      ##
      # Creates new definition. All arguments are required.
      # Nesting is the number of nested blocks in Ruby DSL (this can be
      # basically 0 or 1). Definitions can be only created on the top level scope.
      # Options is a hash with parameters provided for the node.
      # Code is a ruby block that will be evaluated as the body of the node
      ##
      def create_definition(name, options, nesting, &code)
        raise Puppet::Error, "definitions can be only created in top level scope" if nesting > 0
        raise ArgumentError, "no block supplied" if code.nil?

        validate_options [:arguments], options

        definition = Puppet::Resource::Type.new :definition, name.to_s, options
        definition.ruby_code << Context.new(code, :filename => @filename, :nesting => nesting + 1)

        Parser.known_resource_types.add_definition definition
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
        raise Puppet::Error, "Top level resource definitions in Ruby DSL are only available in `site.rb' or equivalent. They are not available from any imported manifest." if Parser.current_scope.nil?

        HashDecorator.new(options, &code) if code

        Array(args).flatten.map do |name|
          ##
          # Implementation based on
          # lib/puppet/parser/functions/create_resources.rb
          ##
          name  = name.to_s
          scope = Parser.current_scope

          case type
          when :class
            klass = Parser.known_resource_types.find_hostclass '', name
            resource = klass.ensure_in_catalog scope, options
          else
            resource = Puppet::Parser::Resource.new(
              type, name, :scope => scope, :source => scope.source
            )

            options.each do |key, val|
              resource[key] = get_resource(val)
            end

            resource.virtual  = true if virtualizing? or options[:virtual]
            resource.exported = true if exporting?    or options[:export]

            definition = Parser.known_resource_types.definition name
            definition.instantiate_resource scope, resource if definition

            scope.compiler.add_resource scope, resource
          end
          resource
        end
      end

      ##
      # Calls a puppet function. It behaves exactly the same way as
      # call_function method in Puppet::DSL::Context.
      ##
      def call_function(name, *args)
        # when performing type import the scope is nil
        raise Puppet::Error, "Top level function calls in Ruby DSL are only available in `site.rb' or equivalend. They are not available from any imported manifest." if Parser.current_scope.nil?

        # Mangle method name for puppet internals
        name = "function_#{name}" unless name.to_s[0...9] == "function_"

        # No, this is not an error. Scope#function_* expects an array
        # as the second argument.
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

      ##
      # Exports resources passed in as an array. It also allows resource
      # references.
      ##
      def export_resources(resources)
        resources.flatten.each do |r|
          get_resource(r).exported = true
        end
      end

      ##
      # Virtualizes resources passed in as an array. It also allows resource
      # references and string references.
      ##
      def virtualize_resources(resources)
        resources.flatten.each do |r|
          get_resource(r).virtual = true
        end
      end

      private

      ##
      # Returns a resource for the passed reference
      ##
      def get_resource(reference)
        case reference
        when Puppet::Resource
          reference
        when ResourceReference
          reference.resource
        when String
          # Try to look up a resource by String, if it fails (function returns
          # nil) just return the string
          resource = Puppet::DSL::Parser.current_scope.findresource(reference)
          resource ||= reference
        else
          # All values have to be stringified before passing to Puppet Core
          reference.to_s
        end
      end

    end
  end
end

