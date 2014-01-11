module Puppet::Environments
  class OnlyProduction
    def search_paths
      []
    end

    def list
      [Puppet::Node::Environment.new(:production)]
    end
  end
end
