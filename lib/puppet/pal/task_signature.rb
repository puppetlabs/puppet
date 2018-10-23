module Puppet
module Pal
  # A TaskSignature is returned from `task_signature`. Its purpose is to answer questions about the task's parameters
  # and if it can be run/called with a hash of named parameters.
  #
  class TaskSignature
    def initialize(task)
      @task = task
    end

    # Returns whether or not the given arguments are acceptable when running the task.
    # In addition to returning the boolean outcome, if a block is given, it is called with a string of formatted
    # error messages that describes the difference between what was given and what is expected. The error message may
    # have multiple lines of text, and each line is indented one space.
    #
    # @param args_hash [Hash] a hash mapping parameter names to argument values
    # @yieldparam [String] a formatted error message if a type mismatch occurs that explains the mismatch
    # @return [Boolean] if the given arguments are acceptable when running the task
    #
    def runnable_with?(args_hash)
      params = @task.parameters
      params_type = if params.nil?
        T_GENERIC_TASK_HASH
      else
        Puppet::Pops::Types::TypeFactory.struct(params)
      end
      return true if params_type.instance?(args_hash)

      if block_given?
        tm = Puppet::Pops::Types::TypeMismatchDescriber.singleton
        error = if params.nil?
          tm.describe_mismatch('', params_type, Puppet::Pops::Types::TypeCalculator.infer_set(args_hash))
        else
          tm.describe_struct_signature(params_type, args_hash).flatten.map {|e| e.format }.join("\n")
        end
        yield "Task #{@task.name}:\n#{error}"
      end
      false
    end

    # Returns the Task instance as a hash
    #
    # @return [Hash{String=>Object}] the hash representation of the task
    def task_hash
      @task._pcore_init_hash
    end

    # Returns the Task instance which can be further explored. It contains all meta-data defined for
    # the task such as the description, parameters, output, etc.
    #
    # @return [Puppet::Pops::Types::PuppetObject] An instance of a dynamically created Task class
    def task
      @task
    end
  end

end
end
