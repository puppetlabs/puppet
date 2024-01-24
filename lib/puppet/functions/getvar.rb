# frozen_string_literal: true

# Digs into a variable with dot notation to get a value from a structure.
#
# **To get the value from a variable** (that may or may not exist), call the function with
# one or two arguments:
#
# * The **first** argument must be a string, and must start with a variable name without leading `$`,
#   for example `get('facts')`. The variable name can be followed
#   by a _dot notation navigation string_ to dig out a value in the array or hash value
#   of the variable.
# * The **optional second** argument can be any type of value and it is used as the
#   _default value_ if the function would otherwise return `undef`.
# * An **optional lambda** for error handling taking one `Error` argument.
#
# **Dot notation navigation string** -
# The dot string consists of period `.` separated segments where each
# segment is either the index into an array or the value of a hash key.
# If a wanted key contains a period it must be quoted to avoid it being
# taken as a segment separator. Quoting can be done with either
# single quotes `'` or double quotes `"`. If a segment is
# a decimal number it is converted to an Integer index. This conversion
# can be prevented by quoting the value.
#
# @example Getting the value of a variable
# ```puppet
# getvar('facts') # results in the value of $facts
# ```
#
# @example Navigating into a variable
# ```puppet
# getvar('facts.os.family') # results in the value of $facts['os']['family']
# ```
#
# @example Using a default value
# ```puppet
# $x = [1,2,[{'name' =>'waldo'}]]
# getvar('x.2.1.name', 'not waldo')
# # results in 'not waldo'
# ```
#
# For further examples and how to perform error handling, see the `get()` function
# which this function delegates to after having resolved the variable value.
#
# @since 6.0.0 - the ability to dig into the variable's value with dot notation.
#
Puppet::Functions.create_function(:getvar, Puppet::Functions::InternalFunction) do
  dispatch :get_from_navigation do
    scope_param
    param 'Pattern[/\A(?:::)?(?:[a-z]\w*::)*[a-z_]\w*(?:\.|\Z)/]', :get_string
    optional_param 'Any', :default_value
    optional_block_param 'Callable[1,1]', :block
  end

  argument_mismatch :invalid_variable_error do
    param 'String', :get_string
    optional_param 'Any', :default_value
    optional_block_param 'Callable', :block
  end

  def invalid_variable_error(navigation, default_value = nil, &block)
    _("The given string does not start with a valid variable name")
  end

  # Gets a result from a navigation string starting with $var
  #
  def get_from_navigation(scope, navigation, default_value = nil, &block)
    # asserted to start with a valid variable name - dig out the variable
    matches = navigation.match(/^((::)?(\w+::)*\w+)(.*)\z/)
    navigation = matches[4]
    if navigation[0] == '.'
      navigation = navigation[1..]
    else
      unless navigation.empty?
        raise ArgumentError, _("First character after var name in get string must be a '.' - got %{char}") % { char: navigation[0] }
      end
    end
    get_from_var_name(scope, matches[1], navigation, default_value, &block)
  end

  # Gets a result from a $var name and a navigation string
  #
  def get_from_var_name(scope, var_string, navigation, default_value = nil, &block)
    catch(:undefined_variable) do
      return call_function_with_scope(scope, 'get', scope.lookupvar(var_string), navigation, default_value, &block)
    end
    default_value
  end
end
