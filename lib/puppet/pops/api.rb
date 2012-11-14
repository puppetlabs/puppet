# Require this to require everything in the pops api

module Puppet
  module Pops    
    module API
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
    end
  end
end
# require all contributions to the api, except the model
require 'puppet/pops/api/named_entry'
require 'puppet/pops/api/scope'
require 'puppet/pops/api/utils'
require 'puppet/pops/api/adaptable'
require 'puppet/pops/api/visitable'
require 'puppet/pops/api/visitor'
require 'puppet/pops/api/evaluator'
require 'puppet/pops/api/containment'

#--
# Map API names 
# This enables reference to the names in the API without future concern that support for more
# than one API requires clients to update all their named references
module Puppet::Pops
  NamedEntry              = Puppet::Pops::API::NamedEntry
  Scope                   = Puppet::Pops::API::Scope
  NoValueError            = Puppet::Pops::API::NoValueError
  ImmutableError          = Puppet::Pops::API::ImmutableError
  ReservedNameError       = Puppet::Pops::API::ReservedNameError
  NotImplementedError     = Puppet::Pops::API::NotImplementedError
  APINotImplementedError  = Puppet::Pops::API::APINotImplementedError
  EvaluationError         = Puppet::Pops::API::EvaluationError
  Adaptable               = Puppet::Pops::API::Adaptable
  Visitable               = Puppet::Pops::API::Visitable
  Visitor                 = Puppet::Pops::API::Visitor
  Evaluator               = Puppet::Pops::API::Evaluator
  Containment             = Puppet::Pops::API::Containment
end


