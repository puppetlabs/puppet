module Puppet
module Pal

  class ScriptCompiler < Compiler
    # Returns the signature of the given plan name
    # @param plan_name [String] the name of the plan to get the signature of
    # @return [Puppet::Pal::PlanSignature, nil] returns a PlanSignature, or nil if plan is not found
    #
    def plan_signature(plan_name)
      loader = internal_compiler.loaders.private_environment_loader
      func = loader.load(:plan, plan_name)
      if func
        return PlanSignature.new(func)
      end
      # Could not find plan
      nil
    end

    # Returns an array of TypedName objects for all plans, optionally filtered by a regular expression.
    # The returned array has more information than just the leaf name - the typical thing is to just get
    # the name as showing the following example.
    #
    # Errors that occur during plan discovery will either be logged as warnings or collected by the optional
    # `error_collector` array. When provided, it will receive {Puppet::DataTypes::Error} instances describing
    # each error in detail and no warnings will be logged.
    #
    # @example getting the names of all plans
    #   compiler.list_plans.map {|tn| tn.name }
    #
    # @param filter_regex [Regexp] an optional regexp that filters based on name (matching names are included in the result)
    # @param error_collector [Array<Puppet::DataTypes::Error>] an optional array that will receive errors during load
    # @return [Array<Puppet::Pops::Loader::TypedName>] an array of typed names
    #
    def list_plans(filter_regex = nil, error_collector = nil)
      list_loadable_kind(:plan, filter_regex, error_collector)
    end

    # Returns the signature callable of the given task (the arguments it accepts, and the data type it returns)
    # @param task_name [String] the name of the task to get the signature of
    # @return [Puppet::Pal::TaskSignature, nil] returns a TaskSignature, or nil if task is not found
    #
    def task_signature(task_name)
      loader = internal_compiler.loaders.private_environment_loader
      task = loader.load(:task, task_name)
      if task
        return TaskSignature.new(task)
      end
      # Could not find task
      nil
    end

    # Returns an array of TypedName objects for all tasks, optionally filtered by a regular expression.
    # The returned array has more information than just the leaf name - the typical thing is to just get
    # the name as showing the following example.
    #
    # @example getting the names of all tasks
    #   compiler.list_tasks.map {|tn| tn.name }
    #
    # Errors that occur during task discovery will either be logged as warnings or collected by the optional
    # `error_collector` array. When provided, it will receive {Puppet::DataTypes::Error} instances describing
    # each error in detail and no warnings will be logged.
    #
    # @param filter_regex [Regexp] an optional regexp that filters based on name (matching names are included in the result)
    # @param error_collector [Array<Puppet::DataTypes::Error>] an optional array that will receive errors during load
    # @return [Array<Puppet::Pops::Loader::TypedName>] an array of typed names
    #
    def list_tasks(filter_regex = nil, error_collector = nil)
      list_loadable_kind(:task, filter_regex, error_collector)
    end
  end

end
end
