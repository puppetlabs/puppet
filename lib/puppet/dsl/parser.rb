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
      @@frames = []

      ##
      # Creates a new Puppet::DSL::Context and assings it as ruby_code to the
      # main object.
      # It requires +main+ object to respond to +ruby_code=+ and +io+ has to
      # respond to +read+.
      ##
      def self.evaluate(main, io)
        raise ArgumentError, "can't assign ruby code to #{main}" unless main.respond_to? :'ruby_code='
        raise ArgumentError, "can't read from file"              unless io.respond_to?   :read

        options = {}
        options[:filename] = io.path if io.respond_to? :path
        source             = io.read
        code               = proc { instance_eval source, options[:filename] || "dsl_main", 0 }
        main.ruby_code     = Context.new code, options
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
        raise RuntimeError, "scope stack already empty" if @@frames.empty?
        @@frames.pop
      end

    end
  end
end

