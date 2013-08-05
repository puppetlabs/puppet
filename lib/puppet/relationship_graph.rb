require 'puppet/simple_graph'

class Puppet::RelationshipGraph < Puppet::SimpleGraph
  def initialize
    super

    @priority = {}
    @count = 0
  end

  def add_vertex(vertex)
    super

    unless @priority.include?(vertex)
      @priority[vertex] = @count
      @count += 1
    end
  end

  def resource_priority(resource)
    @priority[resource]
  end
end
