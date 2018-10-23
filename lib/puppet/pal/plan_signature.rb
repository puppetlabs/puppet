module Puppet
module Pal
  # A PlanSignature is returned from `plan_signature`. Its purpose is to answer questions about the plans's parameters
  # and if it can be called with a hash of named parameters.
  #
  # @api public
  #
  class PlanSignature
    def initialize(plan_function)
      @plan_func = plan_function
    end

    # Returns true or false depending on if the given PlanSignature is callable with a set of named arguments or not
    # In addition to returning the boolean outcome, if a block is given, it is called with a string of formatted
    # error messages that describes the difference between what was given and what is expected. The error message may
    # have multiple lines of text, and each line is indented one space.
    #
    # @example Checking if signature is acceptable
    #
    #   signature = pal.plan_signature('myplan')
    #   signature.callable_with?({x => 10}) { |errors| raise ArgumentError("Ooops: given arguments does not match\n#{errors}") }
    #
    # @api public
    #
    def callable_with?(args_hash)
      dispatcher = @plan_func.class.dispatcher.dispatchers[0]

      param_scope = {}
      # Assign all non-nil values, even those that represent non-existent parameters.
      args_hash.each { |k, v| param_scope[k] = v unless v.nil? }
      dispatcher.parameters.each do |p|
        name = p.name
        arg = args_hash[name]
        if arg.nil?
          # Arg either wasn't given, or it was undef
          if p.value.nil?
            # No default. Assign nil if the args_hash included it
            param_scope[name] = nil if args_hash.include?(name)
          else
            # parameter does not have a default value, it will be assigned its default when being called
            # we assume that the default value is of the correct type and therefore simply skip
            # checking this
            # param_scope[name] = param_scope.evaluate(name, p.value, closure_scope, @evaluator)
          end
        end
      end

      errors = Puppet::Pops::Types::TypeMismatchDescriber.singleton.describe_struct_signature(dispatcher.params_struct, param_scope).flatten
      return true if errors.empty?
      if block_given?
        yield errors.map {|e| e.format }.join("\n")
      end
      false
    end

    # Returns a PStructType describing the parameters as a puppet Struct data type
    # Note that a `to_s` on the returned structure will result in a human readable Struct datatype as a
    # description of what a plan expects.
    #
    # @return [Puppet::Pops::Types::PStructType] a struct data type describing the parameters and their types
    #
    # @api public
    #
    def params_type
      dispatcher = @plan_func.class.dispatcher.dispatchers[0]
      dispatcher.params_struct
    end
  end

end
end
