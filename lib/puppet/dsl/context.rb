require 'puppet/dsl/blank_slate'
require 'puppet/dsl/container'

module Puppet
  module DSL
    class Context < BlankSlate
      AST = Puppet::Parser::AST

      def initialize(scope, &code)
        @scope = scope
        @objects = []
        @code = code
      end

      def evaluate
        instance_eval &@code
        @objects
      end

      def node(name, options = {}, &block)
        raise if block.nil?
        puts "node: #{name}, #{options.inspect}"

        children = Context.new(:no_scope_set, &block).evaluate
        code = AST::ASTArray.new :children => children
        name = Array(name)
        @objects << AST::Node.new(name, options.merge(:code => code))
      end

      def hostclass(name, options = {}, &block)
        raise if block.nil?
        puts "hostclass: #{options.inspect}"

        children = Context.new(:no_scope_set, &block).evaluate
        code = AST::ASTArray.new :children => children
        name = Array(name)
        @objects << AST::Hostclass.new(name, options.merge(:code => code))
      end

      def define(name, options = {}, &block)
        raise if block.nil?
        puts "definition: #{options.inspect}"

        children = Context.new(:no_scope_set, &block).evaluate
        code = AST::ASTArray.new :children => children
        name = Array(name)
        @objects << AST::Definition.new(name, options.merge(:code => code))
      end

      def method_missing(name, *args, &block)
        if Puppet::Type.type(name)
          options = if block.nil?
                      args.last.is_a?(Hash) ? args.pop : {}
                    else
                      Container.new.to_hash
                    end

          create_resource name, args, options

        elsif Puppet::Parser::Functions.function(name)
          call_function name, args
        else
          super
        end
      end

      def create_resource(type, names, args)
        param = AST::ASTArray.new :children => args.map { |k, v|
          AST::ResourceParam.new :param => k.to_s,
                                 :value => AST::Name.new(:value => v.to_s)
        }

        instances = names.map do |name|
          title = Puppet::Parser::AST::String.new :value => name.to_s
          AST::ResourceInstance.new :title => title, :parameters => param
        end

        resource = AST::Resource.new :type => type.to_s,
                      :instances => AST::ASTArray.new(:children => instances)
        @objects << resource
      end

      # Calls a puppet function
      def call_function(name, args)
        raise NoMethodError unless Puppet::Parser::Functions.function name

        args.map! do |a|
          AST::String.new :value => a
        end

        type = if Puppet::Parser::Functions.rvalue? name
                 :rvalue
               else
                 :statement
               end

        array = AST::ASTArray.new :children => args
        @objects << AST::Function.new(
          :name => name,
          :ftype => type,
          :arguments => array
        )
      end

    end
  end
end

