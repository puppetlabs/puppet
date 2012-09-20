module Puppet
  module DSL
    ##
    # A class that starts evaluation of Ruby manifests.
    # It sets the +ruby_code+ for further evaluation.
    ##
    module Parser

      ##
      # An array of scopes for access by Puppet::DSL::Context
      ##
      def self.frames
        @frames ||= []
      end

      ##
      # Shared known_resource_types object for DSL
      ##
      class << self
        attr_accessor :known_resource_types
      end

      ##
      # Creates a new Puppet::DSL::Context and assings it as ruby_code to the
      # main object.
      # It requires +main+ object to respond to +ruby_code=+ and +io+ has to
      # respond to +read+.
      ##
      def self.prepare_for_evaluation(main, code, filename = "dsl_main")
        block = proc { instance_eval code, filename, 0 }
        main.ruby_code << Context.new(block, :filename => filename)
      end

      ##
      # Returns the current scope.
      ##
      def self.current_scope
        frames.last
      end

      ##
      # Pushes a new scope on a stack.
      ##
      def self.add_scope(scope)
        frames.push scope
      end

      ##
      # Pops a scope from the stack.
      # It'll raise RuntimeError if the stack is already empty.
      ##
      def self.remove_scope
        raise RuntimeError, "scope stack already empty" if @frames.empty?
        @frames.pop
      end

    end
  end
end

