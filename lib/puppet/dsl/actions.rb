require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/type_reference'
require 'puppet/util/methodhelper'

module Puppet
  # @since 3.1 
  # @status EXPERIMENTAL
  module DSL

    # {Puppet::DSL::Context} delegates most calls to this class since itself is based
    # on {BlankSlate}. This simplifies the implementation and makes debugging easier.
    ##
    class Actions
      include Puppet::Util::MethodHelper

      # The filename argument is only used when creating new nodes, definitions
      # or classes.
      # @overload initialize()
      # @overload initialize(filename)
      #   @param filename [String] required when creating nodes, definitions and classes
      #
      def initialize(filename)
        @filename     = filename
        @exporting    = false
        @virtualizing = false
      end

      # Returns type reference to the given type.
      # @param name [String] a type name string
      # @return [TypeReference] to the type of the given name
      def type_reference(name)
        TypeReference.new name
      end

      # Checks whether resource type exists
      # @param name [String] the name of the type
      #
      def is_resource_type?(name)
        type = Puppet::Resource.canonicalize_type(name)
        !!(["Node", "Class"].include? type or
           Puppet::Type.type type or
           Parser.known_resource_types.find_definition '', type or
           Parser.known_resource_types.find_hostclass  '', type)
      end

      # Checks whether Puppet function exists
      # @param [String] the name of the function
      def is_function?(name)
        !!Puppet::Parser::Functions.function(name)
      end

      # Returns object for accessing params hash (an object that responds to #[]).
      # All keys will be stringified
      # @return [#[]] object for looking up parameters
      #
      def params
        Parser.current_scope
      end

      # Creates a new Puppet node. All arguments have to be passed.
      # Nesting is the number of nested blocks in Ruby DSL (this can be
      # basically 0 or 1). Nodes can be only created in the top level scope
      # 
      # @param name [String, Regexp] the name match for hostname
      # @option options [String] :inherits name of parent/super node
      # @param nesting [Fixnum] 0 if topscope else > 0
      # @param code [Proc] the body of the created node, evaluated later as Ruby DSL
      # 
      # @return [void]
      # @raise [NoMethodError] if nesting > 0
      # @raise [ArgumentError] if block is missing
      #
      def create_node(name, options, nesting, &code)
        raise NoMethodError, "nodes can be only created in top level scope" if nesting > 0
        raise ArgumentError, "no block supplied" if code.nil?

        validate_options [:inherits], options

        name   = name.to_s unless name.is_a? Regexp
        parent = options[:inherits].to_s if options[:inherits]
        node = Puppet::Resource::Type.new :node, name, :parent => parent
        node.ruby_code << Context.new(code, :filename => @filename, :nesting => nesting + 1)

        Parser.known_resource_types.add_node node
      end

      # Creates a new hostclass. All arguments are required.
      # Nesting is the number of nested blocks in Ruby DSL (this can be
      # basically 0 or 1). Classes can be only created in the top level scope.
      # 
      # @param name [String] the name of the class
      # @option options [String] :inherits name of parent/super class
      # @option options [Hash] :arguments map of parameter name to value
      # @param nesting [Fixnum] 0 if topscope else > 0
      # @param code [Proc] the body of the created hostclass, evaluated later as Ruby DSL
      # 
      # @return [void]
      # @raise [NoMethodError] if nesting > 0
      # @raise [ArgumentError] if block is missing
      #
      def create_hostclass(name, options, nesting, &code)
        raise NoMethodError, "classes can be only created in top level scope" if nesting > 0
        raise ArgumentError, "no block supplied" if code.nil?

        validate_options [:inherits, :arguments], options

        hostclass = Puppet::Resource::Type.new :hostclass, name.to_s, :arguments => options[:arguments], :parent => options[:inherits].to_s
        hostclass.ruby_code << Context.new(code, :filename => @filename, :nesting => nesting + 1)

        Parser.known_resource_types.add_hostclass hostclass
      end

      # Creates a new definition. All arguments are required.
      # Nesting is the number of nested blocks in Ruby DSL (this can be
      # basically 0 or 1). Definitions can be only created in the top level scope.
      # 
      # @param name [String] the name of the definition
      # @option options [Hash] :arguments map of parameter name to value
      # @param nesting [Fixnum] 0 if topscope else > 0
      # @param code [Proc] the body of the created definition, evaluated later as Ruby DSL
      # 
      # @return [void]
      # @raise [NoMethodError] if nesting > 0
      # @raise [ArgumentError] if block is missing
      #
      def create_definition(name, options, nesting, &code)
        raise NoMethodError, "definitions can be only created in top level scope" if nesting > 0
        raise ArgumentError, "no block supplied" if code.nil?

        validate_options [:arguments], options

        definition = Puppet::Resource::Type.new :definition, name.to_s, options
        definition.ruby_code << Context.new(code, :filename => @filename, :nesting => nesting + 1)

        Parser.known_resource_types.add_definition definition
      end

      # Creates a resource, all arguments are required.
      # Type is a Puppet Type of a resource,
      # Code is a proc that will set additional parameters, can be nil.
      #
      # @overload create_resource(type, args, options, {|r| block})
      # @param type [Symbol] name of resource type
      # @param args [String, Array<String>] one or several instance names
      # @param options [Hash] mapping from resource attribute name to value, including mapping of 
      #   non attribute names :export and :virtual. The set of valid names is determined by the resource type.
      # @yieldparam r [ResourceDecorator] allows manipulating the created resource
      # @param block [ruby] evaluated immediately to allow further manipulation of parameters (can be nil)
      # @return [Puppet::Parser::Resource] the created resource
      # 
      # @raise [NoMethodError] if attempt is made to create resource while manifest is imported
      #
      def create_resource(type, args, options, code)
        # when performing type import the scope is nil
        raise NoMethodError, "resources can't be created in top level scope when importing a manifest" if Parser.current_scope.nil?

        ResourceDecorator.new(options, &code) if code

        Array(args).flatten.map do |name|
          # Implementation based on
          # lib/puppet/parser/functions/create_resources.rb
          #
          name  = name.to_s
          scope = Parser.current_scope

          case type
          when :class
            klass = Parser.known_resource_types.find_hostclass '', name
            resource = klass.ensure_in_catalog scope, options
          else
            resource = Puppet::Parser::Resource.new type, name,
              :scope => scope,
              :source => scope.source
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

      # Calls a puppet function.
      # It does not validate arguments to the function.
      #
      # @example
      #   call_function :notice, "foo"
      #
      # @param name [Symbol] the name of the function
      # @param *args arguments passed to the called function
      # @return [Object, void] what the function returns, or void if function does not produce a r-value.
      #
      # @raise [NoMethodError] if function is not found
      #
      def call_function(name, *args)
        # when performing type import the scope is nil
        raise NoMethodError, "functions can't be called in top level scope when importing a manifest" if Parser.current_scope.nil?
        Parser.current_scope.send name, *args
      end


      # @return [Boolean] flag indicating the _export_ state of a resource
      attr_accessor :exporting
      # @return [Boolean] flag indicating the _virtual_ state of a resource
      attr_accessor :virtualizing

      # Predicate accessor for :exporting
      # @return [Boolean] true of resource is _export_ state, false otherwise
      #
      def exporting?
        !!@exporting
      end

      # Predicate accessor for :virtualizing
      # @return [Boolean] true of resource is _virtual_ state, false otherwise
      def virtualizing?
        !!@virtualizing
      end

      # Exports given resources. Resource references can be used.
      # @see #get_resource #get_resource for what can be passed as a reference
      # @param resources [Array<Object>] resources (via reference) to set in _export_ state.
      # @return [void]
      #
      def export_resources(resources)
        resources.flatten.each do |r|
          get_resource(r).exported = true
        end
      end

      # Virtualizes resources passed in as an array. Resource references can be used.
      # @param resources [Array<Puppet::Parser::Resource] resources to set in _virtual_ state.
      # @return [void]
      #
      def virtualize_resources(resources)
        resources.flatten.each do |r|
          get_resource(r).virtual = true
        end
      end

      private

      # Returns a resource for the passed reference
      # @todo the return of o.to_s is somewhat mysterious and needs an explanation
      #
      # @overload get_resource(resource)
      #   @param resource [Puppet::Resource] a resource
      # @overload get_resource(reference)
      #   @param reference [ResourceReference] a reference to a resource
      # @overload get_resource(name)
      #   @param name [String] a resource name
      # @overload get_resource(o)
      #   @param o [#to_s] ???
      # @return [Puppet::Resource] the dereferenced resource
      # @return [String] if reference can not be dereferenced, or not Resource, ResourceReference or String
      #
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
