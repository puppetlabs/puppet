require 'puppet/dsl/blank_slate'
require 'puppet/dsl/resource_decorator'
require 'puppet/dsl/type_reference'

module Puppet
  module DSL

    ##
    # All the Ruby manifests code is evaluated in Puppet::DSL::Context.
    #
    # Context is based on BlankSlate class and the number of available method
    # is reduced to the bare minimum. Available methods are:
    # - Kernel.raise,
    # - Kernel.require,
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
        if self.const_defined? name
          ref = ::Puppet::DSL::TypeReference.new name.downcase
          self.const_set name, ref
          ref
        else
          raise ::NameError, "resource type `#{name}' not found"
        end
      end

      ##
      # Returns whether a constant is defined.
      # It essentially checks if the type exists.
      # The algorithm is identical to one used in +respond_to?+ method.
      ##
      def self.const_defined?(name)
        type = name.downcase
        super || !!([:node, :class].include? type or
           ::Puppet::Type.type type or
           ::Puppet::DSL::Parser.current_scope.compiler.known_resource_types.definition type
          )
      end

      ##
      # Returns type reference. A fallback method for obtaining type references
      # for Ruby 1.8 users.
      ##
      def type(name)
        if ::Puppet::DSL::Context.const_defined? name
          ::Puppet::DSL::TypeReference.new name.downcase
        else
          raise ::NameError, "resource type `#{name}' not found"
        end
      end
      
      ##
      # Initializes new context.
      #
      # +code+ should be a +Proc+ that will be evaluated during evaluation of a
      # resource.
      ##
      def initialize(code)
        @code = code
      end

      ##
      # Method is called when evaluating resource types.
      # It executes ruby code in context of current scope.
      ##
      def evaluate(scope)
        ::Puppet::DSL::Parser.add_scope scope
        instance_eval &@code
        self
      ensure
        ::Puppet::DSL::Parser.remove_scope
      end

      ##
      # Creates a new node. It will fail when the node already exists.
      # Nodes can be created only in top level scope.
      # It will raise ArgumentError when called withoud block and NoMethodError
      # when called in other scope than toplevel.
      #
      # The block is called when node is evaluated.
      # Node name can be a string or a regex (MLEN:FIXME: not yet implemented).
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
        raise ::ArgumentError if block.nil?
        raise ::NoMethodError unless ::Puppet::DSL::Parser.valid_nesting?

        options.each do |k, _|
          unless :inherits == k
            raise ::ArgumentError, "unrecognized option #{k} in node #{name}"
          end
        end

        params = {}
        params.merge! :parent => options[:inherits] if options[:inherits]
        node = ::Puppet::Resource::Type.new :node, name.to_s, params
        node.ruby_code = ::Puppet::DSL::Context.new block
        ::Puppet::DSL::Parser.current_scope.compiler.known_resource_types.add_node node
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
      #   :inherits - specify parent hostclass (MLEN:FIXME: doesn't work yet)
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
        raise ::ArgumentError if block.nil?
        raise ::NoMethodError unless ::Puppet::DSL::Parser.valid_nesting?

        options.each do |k, _|
          unless [:arguments, :inherits].include? k
            raise ::ArgumentError, "unrecognized option #{k} in hostclass #{name}"
          end
        end

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        params.merge! :parent => options[:inherits] if options[:inherits]

        hostclass = ::Puppet::Resource::Type.new :hostclass, name.to_s, params
        hostclass.ruby_code = ::Puppet::DSL::Context.new block

        ::Puppet::DSL::Parser.current_scope.compiler.known_resource_types.add_hostclass hostclass
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
        raise ::ArgumentError if block.nil?
        raise ::NoMethodError unless ::Puppet::DSL::Parser.valid_nesting?

        options.each do |k, _|
          unless :arguments == k
            raise ::ArgumentError, "unrecognized option #{k} in definition #{name}"
          end
        end

        params = {}
        params.merge! :arguments => options[:arguments] if options[:arguments]
        definition = ::Puppet::Resource::Type.new :definition, name.to_s, params
        definition.ruby_code = ::Puppet::DSL::Context.new block
        ::Puppet::DSL::Parser.current_scope.compiler.known_resource_types.add_definition definition
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
        !!([:node, :class].include? name or
           ::Puppet::Type.type name or
           ::Puppet::DSL::Parser.current_scope.compiler.known_resource_types.definition name)
      end

      ##
      # Checks whether Puppet function exists.
      ##
      def valid_function?(name)
        !!::Puppet::Parser::Functions.function(name)
      end

      ##
      # Method will return true when a function or type exists.
      ##
      def respond_to?(name)
        super or valid_type? name or valid_function? name
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
        raise if name == :virtual
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
      # Returns current scope for access for variables
      ##
      def params
        ::Puppet::DSL::Parser.current_scope
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
        raise ::NoMethodError unless valid_type? type
        options = args.last.is_a?(::Hash) ? args.pop : {}
        scope = ::Puppet::DSL::Parser.current_scope

        ::Kernel::Array(args).map do |name|
          ##
          # Implementation based on
          # lib/puppet/parser/functions/create_resources.rb
          ##
          case type
          when :class
            ::Puppet::DSL::ResourceDecorator.new(options, &block) if block

            ::Puppet::Util.symbolizehash! options
            klass = scope.find_hostclass name
            klass.ensure_in_catalog scope, options
          else
            resource = ::Puppet::Parser::Resource.new type, name,
              :scope => scope,
              :source => scope.source
            ::Puppet::Util.symbolizehash! options
            resource.virtual = true if virtualizing? or options[:virtual] == true
            resource.exported = true if exporting? or options[:export] == true
            options.each do |key, val|
              resource[key] = val.to_s
            end

            ::Puppet::DSL::ResourceDecorator.new(resource, &block) if block

            definition = scope.find_definition name.to_s
            if definition
              definition.instantiate_resource scope, resource
            end
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
        raise ::NoMethodError unless valid_function? name
        ::Puppet::DSL::Parser.current_scope.send name, args
      end

      ##
      # Returns the current value of exporting flag
      ##
      def exporting?
        @exporting
      end

      ##
      # Returns the current value of virtualizing flag
      ##
      def virtualizing?
        @virtualizing
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
            r = r.resource if r.is_a? ::Puppet::DSL::ResourceReference
            r.exported = true
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
            r = r.resource if r.is_a? ::Puppet::DSL::ResourceReference
            r.virtual = true
          end
        end
      end
    end

  end
end

