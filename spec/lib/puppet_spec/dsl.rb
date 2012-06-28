module PuppetSpec
  module DSL

    def evaluate_in_context(&block)
      Puppet::DSL::Context.new(block).evaluate @scope
    end

    def known_resource_types
      @compiler.known_resource_types
    end

  end
end
