module Puppet::Pops
module Validation

# Validator that limits the set of allowed expressions to not include catalog related operations
# @api private
class TasksChecker < Checker4_0
  def in_ApplyExpression?
    top = container(0)
    step = -1
    until container(step) == top do
      return true if container(step).is_a? Puppet::Pops::Model::ApplyExpression
      step -= 1
    end
  end

  def check_Application(o)
    illegalTasksExpression(o)
  end

  def check_CapabilityMapping(o)
    illegalTasksExpression(o)
  end

  def check_CollectExpression(o)
    illegalTasksExpression(o)
  end

  def check_HostClassDefinition(o)
    illegalTasksExpression(o)
  end

  def check_NodeDefinition(o)
    illegalTasksExpression(o)
  end

  def check_RelationshipExpression(o)
    if in_ApplyExpression?
      super(o)
    else
      illegalTasksExpression(o)
    end
  end

  def check_ResourceDefaultsExpression(o)
    if in_ApplyExpression?
      super(o)
    else
      illegalTasksExpression(o)
    end
  end

  def check_ResourceExpression(o)
    if in_ApplyExpression?
      super(o)
    else
      illegalTasksExpression(o)
    end
  end

  def check_ResourceOverrideExpression(o)
    illegalTasksExpression(o)
  end

  def check_ResourceTypeDefinition(o)
    illegalTasksExpression(o)
  end

  def check_SiteDefinition(o)
    illegalTasksExpression(o)
  end

  def check_ApplyExpression(o)
    if in_ApplyExpression?
      acceptor.accept(Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, o, {:operation => o.class.to_s})
    else
      rvalue(o.targets)
    end
  end

  def illegalTasksExpression(o)
    acceptor.accept(Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING, o, {:operation => o.class.to_s})
  end

  def resource_without_title?(o)
    false
  end
end
end
end
