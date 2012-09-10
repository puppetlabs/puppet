require 'puppet/dsl/actions'
require 'puppet/dsl/blank_slate'

module Puppet
  module DSL

    ##
    # All the Ruby manifests code is evaluated in Puppet::DSL::Context.
    #
    # Context is based on BlankSlate class and the number of available method
    # is reduced to the bare minimum. Available methods are:
    # - Object.raise,
    # - Object.require,
    # - all methods in this file,
    # - all methods defined by method_missing.
    #
    # Context is evaluated when the corresponding resource is evaluated during
    # compilation.
    ##
    class Context < BlankSlate

      ##
      # Provides syntactic sugar for resource references.
      # It checks whether a constant exists and returns TypeReference
      # corresponding to that constant. Otherwise it raises NameError.
      # A cached version of TypeReference is created on the first call.
      #
      # For further information look at lib/puppet/dsl/type_reference.rb
      ##
      def self.const_missing(name)
        proxy = ::Puppet::DSL::Actions.new "dsl_main"
        ref = proxy.type_reference name
        const_set name, ref unless proxy.is_resource_type? name
        ref
      end

      ##
      # Returns whether a constant is defined.
      # It essentially checks if the type exists.
      # The algorithm is identical to one used in +respond_to?+ method.
      ##
      def self.const_defined?(name)
        proxy = ::Puppet::DSL::Actions.new "dsl_main"
        proxy.is_resource_type? name
      end

      ##
      # Returns type reference. A fallback method for obtaining type references
      # for Ruby 1.8 users.
      ##
      def type(name)
        @proxy.type_reference name
      end

      ##
      # Initializes new context.
      #
      # +code+ should be a +Proc+ that will be evaluated during evaluation of a
      # resource.
      ##
      def initialize(code, options = {})
        @nesting  = options.fetch(:nesting)  { 0          }
        @filename = options.fetch(:filename) { "dsl_main" }
        @proxy    = ::Puppet::DSL::Actions.new @filename
        @code     = code
      end

      ##
      # Method is called when evaluating resource types.
      # It executes ruby code in context of current scope.
      ##
      def evaluate(scope)
        ::Puppet::DSL::Parser.add_scope scope
        instance_eval &@code
      ensure
        ::Puppet::DSL::Parser.remove_scope
      end

      ##
      # Proxy method for Object#raise
      ##
      def raise(*args)
        ::Object.send :raise, *args
      end

      ##
      # The contents of the block passed to this method will be evaluated in
      # the context of Object instead of BasicObject. This adds access to
      # methods defined in global scope (like +require+).
      ##
      def my(&block)
        @object ||= ::Object.new
        @object.instance_eval &block
      end

      ##
      # Creates a new node. It will fail when the node already exists.
      # Nodes can be created only in top level scope.
      # It will raise ArgumentError when called withoud block and NoMethodError
      # when called in other scope than toplevel.
      #
      # The block is called when node is evaluated.
      # Node name can be a string or a regex
      #
      # Implemented options:
      #   :inherits - specify parent node
      #
      #
      # Example:
      #
      #   node "default", :inherits => "foobar" do
      #     use :foo
      #   end
      #
      ##
      def node(name, options = {}, &block)
        @proxy.create_node(name, options, block, @nesting)
      end

      ##
      # Creates a new hostclass. It will fail when the hostclass already exists.
      # Hostclass can be created only in top level scope.
      # It will raise ArgumentError when called withoud block and NoMethodError
      # when called in other scope than toplevel.
      #
      # Name should be a symbol and block is required.
      # Block is called when the hostclass is evaluated.
      #
      # Implemented options:
      #   :inherits - specify parent hostclass
      #   :arguments - hostclass arguments
      #
      # Example:
      #
      #   hostclass :foo, :arguments => {:message => nil} do
      #     notice params[:message]
      #   end
      #
      ##
      def hostclass(name, options = {}, &block)
        @proxy.create_hostclass(name, options, block, @nesting)
      end

      ##
      # Creates a new definition. It will fail when the definition already
      # exists. Definitions can be created in top level scope. Otherwise this
      # method will raise NoMethodError. When called without block it will raise
      # ArgumentError.
      #
      # Name should be a symbol. The block is required.
      #
      # Implemented options:
      #   :arguments - arguments for a definition
      #
      # Example:
      #
      #   define :foobar, :arguments => {:myparam => "myvalue"} do
      #     notice params[:myparam]
      #   end
      #
      ##
      def define(name, options = {}, &block)
        @proxy.create_definition(name, options, block, @nesting)
      end

      ##
      # A syntax sugar for creating hostclass resources.
      ##
      def use(*args)
        create_resource :class, *args
      end

      ##
      # Checks whether Puppet type exists in the following sequence:
      # - is it a hostclass or node?
      # - is it a builtin type?
      # - is it a defined type?
      ##
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

      ##
      # Provides a syntax sugar for creating resources and calling functions.
      # It creates a cached version of a method after the first use.
      #
      # First it will check whether a resource type exists.
      # If it exists, it'll create a resource.
      # If it doesn't exist, then it'll check whether the function exists.
      # If it exists, it'll call that function.
      # If the function doesn't exist, it'll call super and raise an exception.
      #
      # Example:
      #
      #   notice "foo"
      #
      #   file "/tmp/test", :ensure => :present
      #
      ##
      def method_missing(name, *args, &block)
        if @proxy.is_resource_type? name
          # Creating cached version of a method for future use
          define_singleton_method name do |*a, &b|
            create_resource name, *a, &b
          end

          __send__ name, *args, &block
        elsif @proxy.is_function? name
          # Creating cached version of a method for future use
          define_singleton_method name do |*a|
            call_function name, *a
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
        @filename.to_s
      end

      ##
      # Returns current scope for access for variables
      ##
      def params
        @proxy.params
      end

      ##
      # Creates a resource(s) of a given type.
      # The last argument can be a hash with parameters for the resources.
      # Parameters can be also set by passing a block. (See an example below)
      # For further information on block syntax please look at
      # lib/puppet/dsl/resource_decorator.rb
      # Raises NoMethodError when no valid resource type is found.
      #
      # Returns an array of created resources.
      #
      # Example:
      #
      #   create_resource :file, "/foo/bar", "/tmp/test", :owner => "root" do |f|
      #     f.mode = "0600"
      #     f.ensure = :present
      #   end
      #
      ##
      def create_resource(type, *args, &block)
        options = args.last.is_a?(::Hash) ? args.pop : {}
        @proxy.create_resource(type, args, options, block)
      end

      ##
      # Calls a puppet function.
      # Will raise NoMethodError when no valid function is found.
      # It does not validate arguments for a function.
      #
      # Returns whatever puppet function returns.
      #
      # Example:
      #
      #   call_function :notice, "foo"
      #
      ##
      def call_function(name, *args)
        @proxy.call_function(name, args)
      end

      ##
      # Returns the current value of exporting flag
      ##
      def exporting?
        @proxy.exporting?
      end

      ##
      # Returns the current value of virtualizing flag
      ##
      def virtualizing?
        @proxy.virtualizing?
      end

      ##
      # When called with block, sets exporting flag.
      # Otherwise it sets exported flag for each resource passed as args.
      # Also allows to pass resource references as arguments.
      #
      # Example:
      #
      #   export do
      #     file "foobar", :ensure => :present
      #   end
      #
      # Or:
      #
      #   file "foobar", :ensure => :present
      #
      #   export File["foobar"]
      #
      # Or:
      #
      #   export file("foobar", :ensure => :present)
      #
      ##
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

      ##
      # When called with block, sets virtualizing flag.
      # Otherwise it sets the flag for each resource passed as args.
      # Also allows to pass resource references as arguments.
      #
      # Example:
      #
      #   virtual do
      #     file "foobar", :ensure => :present
      #   end
      #
      # Or:
      #
      #   file "foobar", :ensure => :present
      #
      #   virtual File["foobar"]
      #
      # Or:
      #
      #   virtual file("foobar", :ensure => :present)
      #
      ##
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

