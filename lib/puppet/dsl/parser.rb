module Puppet
  module DSL
    ##
    # A class that starts evaluation of Ruby manifests.
    # It sets the +ruby_code+ for further evaluation.
    ##
    class Parser

      ##
      # An array of scopes for access by Puppet::DSL::Context
      ##
      @@frames = []

      ##
      # Initializes Parser object.
      # It requires +main+ object to respond to +ruby_code=+ and +code+ to be a
      # string of Ruby code.
      ##
      def initialize(main, code)
        raise ArgumentError, "can't assign ruby code to #{main}" unless main.respond_to? :ruby_code=

        @main = main
        @code = proc do
          instance_eval code
        end
      end

      ##
      # Creates a new Puppet::DSL::Context and assings it as ruby_code to the
      # main object.
      ##
      def evaluate
        @main.ruby_code = Context.new(@code)
      end

      ##
      # Returns the top level scope.
      ##
      def self.top_scope
        @@frames.first
      end

      ##
      # Returns the current scope.
      ##
      def self.current_scope
        @@frames.last
      end

      ##
      # Pushes a new scope on a stack.
      ##
      def self.add_scope(scope)
        @@frames.push scope
      end

      ##
      # Pops a scope from the stack.
      # It'll raise RuntimeError if the stack is already empty.
      ##
      def self.remove_scope
        raise RuntimeError, "scope stack already empty" if @@frames.first.nil?
        @@frames.pop
      end

      ##
      # Checks whether nesting for creating definitions, nodes and hostclasses
      # is valid. These resources can be only created in the top level scope.
      ##
      def self.valid_nesting?
        Parser.top_scope == Parser.current_scope
      end

    end
  end
end

