module PuppetSpec
  module DSL

    def prepare_compiler_and_scope
      @compiler = Puppet::Parser::Compiler.new Puppet::Node.new("test")
      @scope = Puppet::Parser::Scope.new @compiler, :source => "test"
    end

    def evaluate_in_context(options = {}, &block)
      nesting = options.fetch(:nesting) { 0      }
      scope   = options.fetch(:scope)   { @scope }
      Puppet::DSL::Context.new(block, nesting).evaluate scope
    end

    def known_resource_types
      @compiler.known_resource_types
    end

    def evaluate_in_scope(scope = @scope)
      Puppet::DSL::Parser.add_scope scope
      yield
    ensure
      Puppet::DSL::Parser.remove_scope
    end

  end
end
