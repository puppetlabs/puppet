require 'puppet/dsl/actions'
require 'puppet/dsl/blank_slate'

module Puppet
  # @since 3.1 
  # @status
  #   EXPERIMENTAL
  module DSL

    ##
    # The Puppet::DSL::Context class is used to evaluate all Puppet Ruby DSL manifest code.
    # (i.e. .rb files containing ruby logic in the Puppet Ruby internal DSL language).
    #
    # The Context class is based on the BlankSlate class and the number of available method
    # is reduced to the bare minimum.
    # 
    # Available methods are:
    #
    # * {Object}.raise,
    # * {Object}.require,
    # * all methods in this file,
    # * all methods defined by {#method_missing}.
    #
    # Context is evaluated when the corresponding resource is evaluated during
    # compilation.
    #
    class Context < BlankSlate

      # Provides syntactic sugar for resource references.
      # Returns a reference to a resource type having the given name.
      # A cached version of TypeReference is created on the first call.
      #
      # @param name [String] the name of the resource type
      # @return [TypeReference]
      # @raise [NameError] if the referenced type does not exist.
      # @see TypeReference TypeReference for further information
      ##
      def self.const_missing(name)
        @proxy ||= ::Puppet::DSL::Actions.new "dsl_main"
        ref = @proxy.type_reference name
        const_set name, ref unless @proxy.is_resource_type? name
        ref
      end

      # Returns whether the given _name_ is defined (i.e. if the type exists).
      # The algorithm is identical to the one used in {#respond_to?}.
      #
      def self.const_defined?(name)
        @proxy ||= ::Puppet::DSL::Actions.new "dsl_main"
        @proxy.is_resource_type? name
      end

      # A fallback method for obtaining type references for Ruby 1.8 users.
      # @return [TypeReference] reference to the type
      #
      def type(name)
        @proxy.type_reference name
      end

      # Initializes new context.
      # @todo Improve the explanation of the :nesting option
      # @param code [Proc] the code to evaluate during evaluation of a resource.
      # @option options [Fixnum] :nesting The context nesting. Defaults to 0
      # @option options [String] :filename The file name where the code originates. Default to "dsl_main"
      #
      def initialize(code, options = {})
        @nesting  = options.fetch :nesting,  0
        @filename = options.fetch :filename, "dsl_main"
        @proxy    = ::Puppet::DSL::Actions.new @filename
        @code     = code
      end

      # Executes ruby code in the context of the given scope.
      # (Called when evaluating resource types).
      # @param scope [Puppet::Parser::Scope] the scope to use when evaluating
      # @param type_collection [Puppet::Resource::TypeCollection] the set of known types
      # @return [Object] what the evaluated code returns.
      #
      def evaluate(scope, type_collection)
        ::Puppet::DSL::Parser.add_scope scope
        ::Puppet::DSL::Parser.known_resource_types = type_collection
        instance_eval &@code
      ensure
        ::Puppet::DSL::Parser.known_resource_types = nil
        ::Puppet::DSL::Parser.remove_scope
      end

      # Proxy method for {Object}.raise
      # @return [!] this method does not return
      # @raise [args[0]] with args[1..-1] as arguments
      # @note This method does not return
      def raise(*args)
        ::Object.send :raise, *args
      end

      # The contents of the block passed to this method will be evaluated in the
      # context of {Object} instead of {BlankSlate}
      # This adds access to methods defined in global scope (like `require`).
      # @param block [{|| block}] the block to evaluate.
      # @return [Object] what the given block returns when evaluated
      def ruby_eval(&block)
        @object ||= ::Object.new
        @object.instance_eval &block
      end

      # Creates a new node in top scope. A node with the same name-match must not
      # already have been created. Nodes can be created only in top scope.
      #
      # The block is called when node is evaluated.
      #
      # @example
      #   node "default", :inherits => "foobar" do
      #     use :foo
      #   end
      #
      # @overload node(name, options={}, {|| block})
      # @param name [String, Regexp] host-name match
      # @option options [String] :inherits name of super/parent node
      # @param block [{|| block}] the block containing Ruby DSL statements
      # @raise [ArgumentError] when called without a block
      # @raise [NoMethodError] when called in a scope other than top scope
      # @return [void] 
      def node(name, options = {}, &block)
        @proxy.create_node(name, options, @nesting, &block)
      end

      # Creates a new hostclass. It is an error to create a new hostclass with 
      # the same name as an existing hostclass. 
      # Hostclasses can only be created in the top level scope.
      #
      # The given _block_ is called when the hostclass is evaluated.
      #
      # @example
      #   hostclass :foo, :arguments => {:message => nil} do
      #     notice params[:message]
      #   end
      #
      # @overload hostclass(name, options={}, {|| block})
      # @param name [Symbol] the name of the class
      # @option options [String] :inherits name of super/parent class
      # @option options [Hash] :arguments mapping of hostclass parameter name to value
      # @param block [{|| block}] the block containing Ruby DSL statements
      # @raise [ArgumentError] when called without block
      # @raise [NoMethodError] when called in a scope other than top scope
      # @return [void] 
      #
      def hostclass(name, options = {}, &block)
        @proxy.create_hostclass(name, options, @nesting, &block)
      end

      # Creates a new definition. It is an error to create a new definition with 
      # the same name as an existing definition. 
      # Definitions can only be created in the top level scope.
      #
      # The given _block_ is called when the definition is evaluated.
      #
      #
      # @example
      #   define :foobar, :arguments => {:myparam => "myvalue"} do
      #     notice params[:myparam]
      #   end
      #
      # @overload define(name, options={}, {|| block})
      # @param name [Symbol] the name of the class
      # @option options [Hash] :arguments mapping of definition parameter name to value
      # @param block [{|| block}] the block containing Ruby DSL statements
      # @raise [ArgumentError] when called without block
      # @raise [NoMethodError] when called in a scope other than top scope
      # @return [void] 
      ##
      def define(name, options = {}, &block)
        @proxy.create_definition(name, options, @nesting, &block)
      end

      # Syntax sugar for creating hostclass resources.
      # This is the same as calling `create_resource(:class, *args)`
      # @see #create_resource
      # @return (see #create_resource)
      #
      def use(*args)
        create_resource :class, *args
      end

      # Checks whether Puppet type exists in the following order:
      #
      # 1. is it a hostclass or node?
      # 2. is it a builtin type?
      # 3. is it a defined type?
      #
      # @return [Boolean] true if the name represents a type, false otherwise
      def valid_type?(name)
        @proxy.is_resource_type? name
      end

      ##
      # Checks whether Puppet function exists.
      ##
      def valid_function?(name)
        @proxy.is_function? name
      end

      ##
      # Method will return true when a function or type exists.
      ##
      def respond_to?(name)
        valid_type? name or valid_function? name
      end

      # Provides syntax sugar for creating resources and calling functions.
      # A cached version of the generated method is created on first use.
      #
      # First it will check if the name is the name of an existing resource type, if so,
      # a resource is created.
      # If the name was not a type, a check is made if the name is the name of an existing
      # function, and if so, this function is called.
      # If the function doesn't exist, the super version is called, which will raise an exception.
      #
      # @example Examples of logic handled by #method_missing
      #   notice "foo"
      #
      #   file "/tmp/test", :ensure => :present
      #
      # @return [Object, void] depends on what was called
      #
      def method_missing(name, *args, &block)
        if @proxy.is_resource_type? name
          # Creating cached version of a method for future use
          define_singleton_method name do |*a, &b|
            options = a.last.is_a?(::Hash) ? a.pop : {}
            @proxy.create_resource(name, a, options, b)
          end

          __send__ name, *args, &block
        elsif @proxy.is_function? name
          # Creating cached version of a method for future use
          define_singleton_method name do |*a|
            @proxy.call_function name, *a
          end

          __send__ name, *args
        else
          super
        end
      end

      ##
      # Returns string description of context
      ##
      def inspect
        @filename.inspect
      end

      ##
      # Returns current scope for access for variables
      ##
      def params
        @proxy.params
      end

      # Creates one or several resources of a given type.
      # The last argument can be a hash with parameters for the resources.
      # Parameters can be also set by passing a block. (See the example below).
      # For further information on block syntax please look at {ResourceDecorator}
      #
      # @example
      #   create_resource :file, "/foo/bar", "/tmp/test", :owner => "root" do |f|
      #     f.mode = "0600"
      #     f.ensure = :present
      #   end
      #
      # @overload create_resource(type, title)
      # @overload create_resource(type, title, {|r| block})
      # @overload create_resource(type, title, parameters, {|r| block})
      # @overload create_resource(type, title, ..., parameters)
      # @overload create_resource(type, title, ..., parameters, {|r| block})
      # @param type [Symbol] the name of the resource type
      # @param title [String] one or more titles (one per resource to create)
      # @param parameters [Hash] mapping of parameter name to value for all created resources
      # @param r [ResourceDecorator] access to the created resource for further manipulation in the given block
      # @param block [ruby] the Ruby DSL statements to execute
      # @return [Array<Puppet::Parser::Resource>] created resources
      # @raise [NoMethodError] when the resource type is not found
      #
      def create_resource(type, *args, &block)
        __send__ type, *args, &block
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
        __send__ name, *args
      end

      # Returns the current value of the _exporting_ flag
      # @return [Boolean] if the resource is marked as _exporting_
      def exporting?
        @proxy.exporting?
      end

      # Returns the current value of the _virtualizing_ flag
      # @return [Boolean] if the resource is marked as _virtual_
      def virtualizing?
        @proxy.virtualizing?
      end

      # Sets the _exporting_ flag for one or several resources.
      # @see #exporting?
      # When called with block, sets exporting flag for all resources created in the block
      # Otherwise it sets exported flag for each resource passed as as an argument
      # Resource references (e.g. `File['name']`) can be used as arguments.
      #
      # @example Like this...
      #   export do
      #     file "foobar", :ensure => :present
      #   end
      #
      # @example Or like this...
      #   file "foobar", :ensure => :present
      #   export File["foobar"]
      #
      # @example Or, this way...
      #   export file("foobar", :ensure => :present)
      #
      # @overload export({|| block})
      # @overload export(reference, ...)
      # @param block [ruby] Ruby DSL statements to execute
      # @param reference [ResourceReference] one or more resource references 
      # @return [void]
      #
      def export(*args, &block)
        if block
          begin
            @proxy.exporting = true
            instance_eval &block
          ensure
            @proxy.exporting = false
          end
        else
          @proxy.export_resources(args)
        end
      end

      # Sets the _virtualizing_ flag for one or several resources.
      # @see #virtualizing?
      # When called with block, sets virtualizing flag for all resources created in the block
      # Otherwise it sets virtualizing flag for each resource passed as as an argument
      # Resource references (e.g. `File['name']`) can be used as arguments.
      #
      # @example Like this...
      #   virtual do
      #     file "foobar", :ensure => :present
      #   end
      #
      # @example Or like this...
      #   file "foobar", :ensure => :present
      #   virtual File["foobar"]
      #
      # @example Or, this way...
      #   virtual file("foobar", :ensure => :present)
      #
      # @overload virtual({|| block})
      # @overload virtual(reference, ...)
      # @param block [ruby] Ruby DSL statements to execute
      # @param reference [ResourceReference] one or more resource references 
      # @return [void]
      #
      def virtual(*args, &block)
        if block
          begin
            @proxy.virtualizing = true
            instance_eval &block
          ensure
            @proxy.virtualizing = false
          end
        else
          @proxy.virtualize_resources(args)
        end
      end
    end

  end
end

