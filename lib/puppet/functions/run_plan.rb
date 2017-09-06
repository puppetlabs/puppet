# Runs the `plan` referenced by its name passing giving arguments to it given as a hash of name to value mappings
# A plan is autoloaded from under <root>/plans if not already defined.
#
# @example defining and running a plan
#   plan myplan($x) { 
#     # do things with tasks
#     notice "plan done with param x = ${x}"
#   }
#   run_plan('myplan', {x => 'testing' }
#
# @since > 5.2 TODO: change this when known
#
Puppet::Functions.create_function(:run_plan, Puppet::Functions::InternalFunction) do
  dispatch :run_plan do
    scope_param
    param 'String', :plan_name
    optional_param 'Hash', :named_args
  end

  def run_plan(scope, plan_name, named_args = {})
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_plan'})
    end

    loaders = closure_scope.compiler.loaders
    # The perspective of the environment is wanted here (for now) to not have to require modules
    # to have dependencies defined in meta data.
    loader = loaders.private_environment_loader
    if loader && func = loader.load(:plan, plan_name)
      # TODO: Add profiling around this
        return func.class.dispatcher.dispatchers[0].call_by_name_with_scope(scope, named_args, true)
    end
    # Could not find plan
    raise ArgumentError, "Function #{self.class.name}(): Unknown plan: '#{plan_name}'"
  end

end

