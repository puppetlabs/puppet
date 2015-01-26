module RelationshipGraphMatchers
  class EnforceOrderWithEdge
    def initialize(before, after)
      @before = before
      @after = after
    end

    def matches?(actual_graph)
      @actual_graph = actual_graph

      @reverse_edge = actual_graph.edge?(
          vertex_called(actual_graph, @after),
          vertex_called(actual_graph, @before))

      @forward_edge = actual_graph.edge?(
          vertex_called(actual_graph, @before),
          vertex_called(actual_graph, @after))

      @forward_edge && !@reverse_edge
    end

    def failure_message
      "expect #{@actual_graph.to_dot_graph} to only contain an edge from #{@before} to #{@after} but #{[forward_failure_message, reverse_failure_message].compact.join(' and ')}"
    end

    def forward_failure_message
      if !@forward_edge
        "did not contain an edge from #{@before} to #{@after}"
      end
    end

    def reverse_failure_message
      if @reverse_edge
        "contained an edge from #{@after} to #{@before}"
      end
    end

    private

    def vertex_called(graph, name)
      graph.vertices.find { |v| v.ref =~ /#{Regexp.escape(name)}/ }
    end
  end

  def enforce_order_with_edge(before, after)
    EnforceOrderWithEdge.new(before, after)
  end
end
