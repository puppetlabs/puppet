module Puppet::ModuleTool
  module Applications
    class Searcher < Application

      def initialize(term, options = {})
        @term = term
        super(options)
      end

      def run
        Puppet::Forge.search(@term)
      end
    end
  end
end
