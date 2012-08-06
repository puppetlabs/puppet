require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/scope_decorator'
require 'puppet/dsl/type_reference'
require 'puppet/dsl/helper'

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
      include ::Puppet::DSL::Helper

      ##
      # Provides syntactic sugar for resource references.
      # It checks whether a constant exists and returns TypeReference
      # corresponding to that constant. Otherwise it raises NameError.
      # A cached version of TypeReference is created on the first call.
      #
      # For further information look at lib/puppet/dsl/type_reference.rb
      ##
      def self.const_missing(name)
        ref = ::Puppet::DSL::TypeReference.new name
        const_set name, ref unless is_resource_type? name
        ref
      end

      ##
      # Returns whether a constant is defined.
      # It essentially checks if the type exists.
      # The algorithm is identical to one used in +respond_to?+ method.
      ##
      def self.const_defined?(name)
        is_resource_type? name
      end

      ##
      # Returns type reference. A fallback method for obtaining type references
      # for Ruby 1.8 users.
      ##
      def type(name)
        ::Puppet::DSL::TypeReference.new name
      end

      ##
      # Initializes new context.
      #
      # +code+ should be a +Proc+ that will be evaluated during evaluation of a
      # resource.
      ##
      def initialize(code, nesting = 0)
        @nesting  = nesting
        @code     = code
        @object   = ::Object.new
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
        raise ::NoMethodError, "called from invalid nesting" if @nesting > 0
        raise ::ArgumentError, "no block supplied"           if block.nil?

        options.each do |k, _|
          unless :inherits == k
            raise ::ArgumentError, "unrecognized option #{k} in node #{name}"
          end
        end

        params = {}
        if options[:inherits]
          options[:inherits] = options[:inherits].to_s unless options[:inherits].is_a? ::Regexp
          params.merge! :parent => options[:inherits]
        end

        name = name.to_s unless name.is_a? ::Regexp
        node = ::Puppet::Resource::Type.new :node, name, params
        node.ruby_code = ::Puppet::DSL::Context.new block, @nesting + 1

        ::Puppet::DSL::Parser.current_scope.known_resource_types.add_node node
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
        raise ::NoMethodError, "called from invalid nesting" if @nesting > 0
        raise ::ArgumentError, "no block supplied"           if block.nil?

        options.each do |k, _|
          unless [:arguments, :inherits].include? k
            raise ::ArgumentError, "unrecognized option #{k} in hostclass #{name}"
          end
        end

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        params.merge! :parent    => options[:inherits].to_s if options[:inherits]

        hostclass = ::Puppet::Resource::Type.new :hostclass, name.to_s, params
        hostclass.ruby_code = ::Puppet::DSL::Context.new block, @nesting + 1

        ::Puppet::DSL::Parser.current_scope.known_resource_types.add_hostclass hostclass
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
        raise ::NoMethodError, "called from invalid nesting" if @nesting > 0
        raise ::ArgumentError, "no block supplied"           if block.nil?

        options.each do |k, _|
          unless :arguments == k
            raise ::ArgumentError, "unrecognized option #{k} in definition #{name}"
          end
        end

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        definition = ::Puppet::Resource::Type.new :definition, name.to_s, params
        definition.ruby_code = ::Puppet::DSL::Context.new block, @nesting + 1

        ::Puppet::DSL::Parser.current_scope.known_resource_types.add_definition definition
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
        is_resource_type? name
      end

      ##
      # Checks whether Puppet function exists.
      ##
      def valid_function?(name)
        is_function? name
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
        if valid_type? name
          # Creating cached version of a method for future use
          define_singleton_method name do |*a, &b|
            create_resource name, *a, &b
          end

          create_resource name, *args, &block
        elsif valid_function? name
          # Creating cached version of a method for future use
          define_singleton_method name do |*a|
            call_function name, *a
          end

          call_function name, *args
        else
          super
        end
      end

      ##
      # Returns string description of context
      ##
      def inspect
        "dsl_main"
      end

      ##
      # Returns current scope for access for variables
      ##
      def params
        ::Puppet::DSL::ScopeDecorator.new(::Puppet::DSL::Parser.current_scope)
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
        # when performing type import the scope is nil
        raise ::NoMethodError, "resources can't be created in top level scope when importing a manifest" if ::Puppet::DSL::Parser.current_scope.nil?

        raise ::NoMethodError, "resource type #{type} not found" unless valid_type? type
        options = args.last.is_a?(::Hash) ? args.pop : {}

        ::Puppet::DSL::ResourceDecorator.new(options, &block) if block

        scope = ::Puppet::DSL::Parser.current_scope
        ::Kernel::Array(args).map do |name|
          ##
          # Implementation based on
          # lib/puppet/parser/functions/create_resources.rb
          ##
          name = name.to_s

          case type
          when :class
            klass = ::Puppet::DSL::Parser.current_scope.known_resource_types.find_hostclass '', name
            klass.ensure_in_catalog scope, options
          else
            resource = ::Puppet::Parser::Resource.new type, name,
              :scope => scope,
              :source => scope.source
            options.each do |key, val|
              resource[key] = get_resource(val) || val.to_s
            end

            resource.virtual = true if virtualizing? or options[:virtual] == true
            resource.exported = true if exporting? or options[:export] == true

            definition = scope.known_resource_types.definition name
            definition.instantiate_resource scope, resource if definition

            scope.compiler.add_resource scope, resource
          end
          resource
        end
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
        # when performing type import the scope is nil
        raise ::NoMethodError, "resources can't be created in top level scope when importing a manifest" if ::Puppet::DSL::Parser.current_scope.nil?

        raise ::NoMethodError, "calling undefined function #{name}(#{args.join ', '})" unless valid_function? name
        ::Puppet::DSL::Parser.current_scope.send name, args
      end

      ##
      # Returns the current value of exporting flag
      ##
      def exporting?
        !!@exporting
      end

      ##
      # Returns the current value of virtualizing flag
      ##
      def virtualizing?
        !!@virtualizing
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
            @exporting = true
            instance_eval &block
          ensure
            @exporting = false
          end
        else
          args.flatten.each do |r|
            get_resource(r).exported = true
          end
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
            @virtualizing = true
            instance_eval &block
          ensure
            @virtualizing = false
          end
        else
          args.flatten.each do |r|
            get_resource(r).virtual = true
          end
        end
      end
    end

  end
end

