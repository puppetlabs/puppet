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

    end
  end
end

