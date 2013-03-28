# Visitable is a mix-in module that makes a class visitable by a Visitor
module Puppet::Pops::API::Visitable
  def accept(visitor, *arguments)
    visitor.visit(self, *arguments)
  end
end
