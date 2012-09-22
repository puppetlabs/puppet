require 'forwardable'

module Puppet
  module DSL
    ##
    # A class that starts evaluation of Ruby manifests.
    # It sets the +ruby_code+ for further evaluation.
    # This is intended to be used as singleton.
    ##
    module Parser
      extend Forwardable
      #
      # For cleaner code - no need to define class methods everywhere and open
      # metaclasses for `attr_accessor`, etc.
      extend self

      ##
      # An array of scopes for access by Puppet::DSL::Context
      ##
      def frames
        @frames ||= []
      end

      ##
      # Shared known_resource_types object for DSL
      ##
      attr_accessor :known_resource_types

      ##
      # Creates a new Puppet::DSL::Context and assings it as ruby_code to the
      # main object.
      # It requires +main+ object to respond to +ruby_code+ and return
      # collection responding to +<<+.
      ##
      def prepare_for_evaluation(main, code, filename = "dsl_main")
        block = proc { instance_eval code, filename, 0 }
        main.ruby_code << Context.new(block, :filename => filename)
      end

      ##
      # Returns the current scope.
      ##
      def_delegator :frames, :last, :current_scope

      ##
      # Pushes a new scope on a stack.
      ##
      def_delegator :frames, :push, :add_scope

      ##
      # Pops a scope from the stack.
      # It'll raise RuntimeError if the stack is already empty.
      ##
      def self.remove_scope
        raise RuntimeError, "scope stack already empty" if frames.empty?
        frames.pop
      end

    end
  end
end

