module Puppet::ModuleTool
  module Applications
    class Searcher < Application

      def initialize(term, forge, options = {})
        @term = term
        @forge = forge
        super(options)
      end

      def run
        @forge.search(@term)
      end
    end
  end
end
