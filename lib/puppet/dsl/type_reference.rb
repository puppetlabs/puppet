require 'puppet/parser/collector'
require 'puppet/parser/resource/param'
require 'puppet/dsl/resource_reference'
require 'puppet/dsl/hash_decorator'
require 'puppet/dsl/parser'

module Puppet
  module DSL
    ##
    # TypeReference object is returned by +Context#const_missing+.
    # It allows to set defaults, create collections and get references for
    # resources of given type.
    ##
    class TypeReference

      ##
      # Returns Puppet type represented by this reference
      ##
      attr_reader :type_name
      alias to_s type_name

      ##
      # Creates new TypeReference.
      # Raises NameError when resource type is not found
      ##
      def initialize(typename)
        name = Puppet::Resource.canonicalize_type typename
        if Puppet::DSL::Context.const_defined? name
          @type_name = name
          @cache = {}
        else
          raise NameError, "resource type `#{name}' not found"
        end
      end

      ##
      # Returns a ResourceReference.
      # Raises ArgumentError when resource cannot be found.
      # Method caches references for future use.
      ##
      def [](reference)
        @cache[reference] ||= Puppet::DSL::ResourceReference.new self, reference
      end

      ##
      # Method creates a collection for exported resources.
      # Raises Puppet::Error when reference is created when called from imported
      # file.
      ##
      def collect
        raise Puppet::Error, "Exporting collections on top level scope in Ruby DSL is only available in `site.rb' or equivalent. They are not available from any imported manifest." if Parser.current_scope.nil?

        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type_name, nil, nil, :exported
        scope.compiler.add_collection c
        c
      end

      ##
      # Method creates a collection for virtual resources.
      # Raises Puppet::Error when reference is created when called from imported
      # file.
      ##
      def realize
        raise Puppet::Error, "Realizing collections on top level scope in Ruby DSL is only available in `site.rb' or equivalent. They are not available from any imported manifest." if Parser.current_scope.nil?

        scope = Puppet::DSL::Parser.current_scope
        c = Puppet::Parser::Collector.new scope, @type_name, nil, nil, :virtual
        scope.compiler.add_collection c
        c
      end

      ##
      # Method allows to set defaults for a resource type.
      # Raises Puppet::Error when reference is created when called from imported
      # file.
      ##
      def defaults(options = {}, &block)
        raise Puppet::Error, "Setting defaults on top level scope in Ruby DSL is only available in `site.rb' or equivalent. They are not available from any imported manifest." if Parser.current_scope.nil?

        if options != {} or block
          Puppet::DSL::HashDecorator.new(options, &block) unless block.nil?

          # for compatibility with Puppet parser
          options = options.map do |k, v|
            Puppet::Parser::Resource::Param.new :name => k, :value => v
          end
          Puppet::DSL::Parser.current_scope.define_settings @type_name, options
        end

        result = {}
        Puppet::DSL::Parser.current_scope.lookupdefaults(@type_name).map do |_, v|
          result[v.name] = v.value
        end
        result
      end

    end
  end
end

