require 'semantic/dependency'

module Semantic
  module Dependency
    class UnsatisfiableGraph < StandardError
      attr_reader :graph

      def initialize(graph)
        @graph = graph

        deps = sentence_from_list(graph.modules)
        super "Could not find satisfying releases for #{deps}"
      end

      private

      def sentence_from_list(list)
        case list.length
        when 1
          list.first
        when 2
          list.join(' and ')
        else
          list = list.dup
          list.push("and #{list.pop}")
          list.join(', ')
        end
      end
    end
  end
end
