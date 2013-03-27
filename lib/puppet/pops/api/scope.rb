require 'puppet/pops/api'

module Puppet::Pops::API
  class Scope
    # Looks up variable when given a single variable name as argument:
    #  ascope['varname']
    # Looks up data when given two arguments, type, and name:
    #  ascope['typename', 'instance_name']
    #
    # Produces a frozen instance of Puppet::Pops::API::NamedEntry
    def [] (*args)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Sets the numeric variables $0 to $n based on the result of a regular expression
    # match operation. Calling this method replaces any previously set values. If nil
    # is given, the variables are cleared and will produce nil if referenced.
    #
    def set_match_data(match_data = nil, origin = nil)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Returns the value of the given variable name. If name does not exist, the optional missing_value
    # is returned. For name/scope resolution see #get_variable_entry
    # Raises: NoValueError if there is no entry for name, and missing_value is not given (or given as nil).
    #
    def get_variable(name, missing_value = nil)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Returns the entry for the given variable name. If the name does not ecists, nil is returned,
    # otherwise a NamedEntry
    #
    def get_variable_entry(name)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Returns the value of the given type/name. If type/name does not exist, the optional missing_value
    # is returned. For name/scope resolution see #get_data_entry
    # Raises NoValueError if there is no entry for name, and missing_value is not given (or given as nil).
    #
    def get_data(type, name, missing_value = nil)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Returns the entry for the given type/name, or nil if no such type/name exists. The returned
    # entry is a NamedEntry.
    #
    def get_data_entry(type, name)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Sets the value of the given type/name in this or a parent scope depending on the type of
    # scope. See #is_top_scope?, #is_named_scope?, and #is_local_scope? for more information.
    #
    def set_data(type, name, value, origin = nil)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Sets the variable named with the given name in this scope. The optional origin is a URI or
    # producer of an URI responding to #uri() denoting the
    # location of the instruction that caused this variable to be set).
    # If the given name is absolute, it is changed to a relative name.
    #
    # Raises: NameError if name is numeric.
    #
    def set_variable(name, value, origin = nil)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Returns true if the scope is a top scope (has no parent scope and holds all values
    # that can be referenced from anywhere).
    #
    def is_top_scope?
      false
    end

    # Returns true if the scope is a named scope (has a name and a parent scope) and prepends its name
    # to all variables assigned in the scope. Only allows non qualified and relative variable
    # names to be assigned. All variables and data are propagated to the parent scope (which typically
    # is a top scope).
    #
    def is_named_scope?
      false
    end

    # Returns true if the scope is a local scope (unnamed, has a parent scope). All variables are set
    # in the local scope and set variables shadow all other variables. Only allows non qualified and
    # relative variables to be set.
    # Setting of any other type is delegated to the parent scope.
    #
    def is_local_scope?
      false
    end

    # Produces a nested named scope with the given name
    def named_scope(name)
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Produces a nested local scope.
    def local_scope
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # Returns the parent scope, or nil, if #is_top_scope? is true
    def parent_scope
      raise Puppet::Pops::API::APINotImplementedError.new
    end

    # TODO: Explore how to deal with reserved names
    #          # Reserves a name - it is not set, but can later not be assigned by user. The argument
    #          # type is a type, or the special type :variable.
    #          #
    #          def reserve_name(type, name)
    #            raise Puppet::Pops::API::APINotImplementedError.new
    #          end
    #
    #          def is_reserved?(type, name)
    #            raise Puppet::Pops::API::APINotImplementedError.new
    #          end
  end
end
