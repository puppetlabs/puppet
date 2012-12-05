module Puppet
  # @since 3.1 
  # @status EXPERIMENTAL
  module DSL
    # Initializes evaluation of Ruby based manifests.
    module Parser

      # @return [Array<Puppet::Parser::Scope>] for access by Puppet::DSL::Context
      #
      def self.frames
        @frames ||= []
      end

      class << self
        # @return [Puppet::Resource::TypeCollection] Shared known_resource_types object for DSL
        #
        attr_accessor :known_resource_types
      end

      # Creates a new Puppet::DSL::Context and assings it as _ruby_code_ to the
      # main object.
      # @param main [#ruby_code] where the ruby _code_ is set
      # @param code [{|| block}] the ruby code to prepare for evaluation
      # @param filename [String] name of file where code originates from
      # @return [void]
      #
      def self.prepare_for_evaluation(main, code, filename = "dsl_main")
        block = proc { instance_eval code, filename, 0 }
        main.ruby_code << Context.new(block, :filename => filename)
      end

      # @return [Puppet::Parser::Scope] the current scope
      #
      def self.current_scope
        frames.last
      end


      # Pushes a new scope on a stack.
      # @return [Puppet::Parser::Scope] the given scope
      #
      def self.add_scope(scope)
        frames.push scope
      end

      # Pops a scope from the stack.
      # @raise [RuntimeError] unless stack has at least one item
      #
      def self.remove_scope
        raise RuntimeError, "scope stack already empty" if @frames.empty?
        @frames.pop
      end

    end
  end
end

