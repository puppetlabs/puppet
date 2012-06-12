require 'puppet/dsl/blank_slate'

module Puppet
  module DSL
    class Context

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
        code = Puppet::Parser::AST::ASTArray.new :children => children
        name = Array(name)
        @objects << Puppet::Parser::AST::Node.new(name, options.merge(:code => code))
      end

      def hostclass(name, options = {}, &block)
        raise if block.nil?
        puts "hostclass: #{options.inspect}"

        children = Context.new(:no_scope_set, &block).evaluate
        code = Puppet::Parser::AST::ASTArray.new :children => children
        name = Array(name)
        @objects << Puppet::Parser::AST::Hostclass.new(name, options.merge(:code => code))
      end

      def define(name, options = {}, &block)
        raise if block.nil?
        puts "definition: #{options.inspect}"

        children = Context.new(:no_scope_set, &block).evaluate
        code = Puppet::Parser::AST::ASTArray.new :children => children
        name = Array(name)
        @objects << Puppet::Parser::AST::Definition.new(name, options.merge(:code => code))
      end

      def method_missing(*args, &block)
        puts "#{args.shift}: #{args.inspect}"
      end

    end
  end
end

