module PuppetSpec
  module DSL

    def prepare_compiler_and_scope_for_evaluation
      let(:compiler) { Puppet::Parser::Compiler.new Puppet::Node.new("test") }
      let(:scope)    { Puppet::Parser::Scope.new compiler, :source => "test" }
    end

    def evaluate_in_context(options = {}, &block)
      eval_scope = options.fetch :scope, scope
      Puppet::DSL::Context.new(block, options).evaluate eval_scope, eval_scope.known_resource_types
    end

    def known_resource_types
      compiler.known_resource_types
    end

    def evaluate_in_scope(options = {})
      eval_scope = options.fetch :scope, scope
      Puppet::DSL::Parser.add_scope eval_scope
      Puppet::DSL::Parser.known_resource_types = eval_scope.known_resource_types
      yield
    ensure
      Puppet::DSL::Parser.known_resource_types = nil
      Puppet::DSL::Parser.remove_scope
    end

  end
end
