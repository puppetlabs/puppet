# Require this to require everything in the pops api

module Puppet
  module Pops
    # Raised if a referenced value does not exist (has not been set) and a method
    # guarantees a value result that may include nil.
    class NoValueError < NameError
    end

    # Raised if an attempt is made to change/set an immutable value
    class ImmutableError < StandardError
    end

    # Raised when there is an attempt to set a reserved name
    class ReservedNameError < ArgumentError
    end

    # Raised when an implementation of a method is pending (to make it fail in a manner
    # different than does not respond to...
    class NotImplementedError
    end

    # Raised when an API method is not implemented (internal error)
    class APINotImplementedError < NotImplementedError
    end

    # Raised when there is an evaluation error
    class EvaluationError < StandardError
    end

    module API
      require 'puppet/pops/api/patterns'
      require 'puppet/pops/api/utils'

      require 'puppet/pops/api/adaptable'
      require 'puppet/pops/api/adapters'

      require 'puppet/pops/api/visitable'
      require 'puppet/pops/api/visitor'

      require 'puppet/pops/api/named_entry'
      require 'puppet/pops/api/scope'
      require 'puppet/pops/api/evaluator'
      require 'puppet/pops/api/executor'
      require 'puppet/pops/api/containment'
      require 'puppet/pops/api/loader'
      require 'puppet/pops/api/origin'

      require 'puppet/pops/api/issues'
      require 'puppet/pops/api/label_provider'
      require 'puppet/pops/api/validation'

      require 'puppet/pops/api/model/model'
    end
  end
end

# Unfinished
# require 'puppet/pops/api/model/catalog'
# require 'puppet/pops/api/model/runtime'
