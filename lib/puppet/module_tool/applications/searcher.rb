module Puppet::Module::Tool
  module Applications
    class Searcher < Application

      def initialize(term, options = {})
        @term = term
        @forge = Puppet::Forge::Forge.new
        super(options)
      end

      def run
        @forge.search(@term)
      end
    end
  end
end
