# Digs into a variable or value with dot notation to get a value from a structure.
#
# **To get the value from a variable** (that may or may not exist), call the function with
# one or two arguments:
#
# * The **first** argument must be a string, and must start with `$` followed by the name
#   of the variable - for example `get('$facts')`. The variable name can be followed
#   by a _dot notation navigation string_ to dig out a value in the array or hash value
#   of the variable.
# * The **optional second** argument can be any type of value and it is used as the
#   _default value_ if the function would otherwise return `undef`.
# * An **optional lambda** for error handling taking one `Error` argument.
#
# **To dig into a given value**, call the function with (at least) two arguments:
#
# * The **first** argument must be an Array, or Hash. Value can also be `undef`
#   (which also makes the result `undef` unless a _default value_ is given).
# * The **second** argument must be a _dot notation navigation string_.
# * The **optional third** argument can be any type of value and it is used
#   as the _default value_ if the function would otherwise return `undef`.
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
# get('$facts') # results in the value of $facts
# ```
#
# @example Navigating into a variable
# ```puppet
# get('$facts.os.family') # results in the value of $facts['os']['family']
# ```
#
# @example Getting the value from an expression
# ```puppet
# get($facts, 'os.family') # results in the value of $facts['os']['family']
# $facts.get('os.family')  # the same as above
# get([1,2,[{'name' =>'waldo'}]], '2.0.name') # results in 'waldo'
# ```
#
# @example Using a default value
# ```puppet
# get([1,2,[{'name' =>'waldo'}]], '2.1.name', 'not waldo')
# # results in 'not waldo'
# ```
#
# @example Quoting a key with period
# ```puppet
# $x = [1, 2, { 'readme.md' => "This is a readme."}]
# $x.get('2."readme.md"')
# ```
#
# @example Quoting a numeric string
# ```puppet
# $x = [1, 2, { '10' => "ten"}]
# $x.get('2."0"')
# ```
#
# **Error Handling** - There are two types of common errors that can
# be handled by giving the function a code block to execute.
# (A third kind or error; when the navigation string has syntax errors
# (for example an empty segment or unbalanced quotes) will always raise
# an error).
#
# The given block will be given an instance of the `Error` data type,
# and it has methods to extract `msg`, `issue_code`, `kind`, and
# `details`.
#
# The `msg` will be a preformatted message describing the error.
# This is the error message that would have surfaced if there was
# no block to handle the error.
#
# The `kind` is the string `'SLICE_ERROR'` for both kinds of errors,
# and the `issue_code` is either the string `'EXPECTED_INTEGER_INDEX'`
# for an attempt to index into an array with a String,
# or `'EXPECTED_COLLECTION'` for an attempt to index into something that
# is not a Collection.
#
# The `details` is a Hash that for both issue codes contain the
# entry `'walked_path'` which is an Array with each key in the
# progression of the dig up to the place where the error occurred.
#
# For an `EXPECTED_INTEGER_INDEX`-issue the detail `'index_type'` is
# set to the data type of the index value and for an
# `'EXPECTED_COLLECTION'`-issue the detail `'value_type'` is set
# to the type of the value.
#
# The logic in the error handling block can inspect the details,
# and either call `fail()` with a custom error message or produce
# the wanted value.
#
# If the block produces `undef` it will not be replaced with a
# given default value.
#
# @example Ensure `undef` result on error
# ```puppet
# $x = 'blue'
# $x.get('0.color', 'green') |$error| { undef } # result is undef
#
# $y = ['blue']
# $y.get('color', 'green') |$error| { undef } # result is undef
# ```
#
# @example Accessing information in the Error
# ```puppet
# $x = [1, 2, ['blue']]
# $x.get('2.color') |$error| {
#   notice("Walked path is ${error.details['walked_path']}")
# }
# ```
# Would notice `Walked path is [2, color]`
#
# Also see the `dig()` function which is similar but uses an
# array of navigation values instead of a dot notation string.
#
# @since 6.0.0
#
Puppet::Functions.create_function(:get, Puppet::Functions::InternalFunction) do
  dispatch :get_from_navigation do
    scope_param
    param 'Pattern[/\A\$[a-z]/]', :get_string
    optional_param 'Any', :default_value
    optional_block_param 'Callable[1,1]', :block
  end

  dispatch :get_from_value do
    param 'Any', :value
    param 'String', :dotted_string
    optional_param 'Any', :default_value
    optional_block_param 'Callable[1,1]', :block
  end

  # Gets a result from a navigation string starting with $var
  #
  def get_from_navigation(scope, navigation, default_value = nil)
    # asserted to start with a valid variable name - dig out the variable
    matches = navigation.match(/^(\$(::)?(\w+::)*\w+)(.*)\z/)
    navigation = matches[4]
    if navigation[0] == '.'
      navigation = navigation[1..-1]
    else
      unless navigation.empty?
        raise ArgumentError, _("First character after $var name in get string must be a '.' - got %{char}") % {char: navigation[0]}
      end
    end
    get_from_var_name(scope, matches[1], navigation, default_value)
  end

  # Gets a result from a $var name and a navigation string
  #
  def get_from_var_name(scope, var_string, navigation, default_value = nil, &block)
    catch(:undefined_variable) do
      # skip the leading $ in var_string when looking up the var
      return get_from_value(scope.lookupvar(var_string[1..-1]), navigation, default_value, &block)
    end
    default_value
  end

  # Gets a result from given value and a navigation string
  #
  def get_from_value(value, navigation, default_value = nil, &block)
    return default_value if value.nil?
    return value if navigation.empty?
    # split_key expects an initial key - which is not used in this context
    # add a fake (x)  first and then throw it away
    segments = split_key("x." + navigation) {|err| _("Syntax error in dotted-navigation string")}
    segments.shift
    begin
      result = call_function('dig', value, *segments)
      return result.nil? ? default_value : result
    rescue Puppet::ErrorWithData => e
      if block_given?
        # TRANSLATORS, do not translate this string - it is an issue code
        yield(e.error_data)
      else
        raise e
      end
    # rescue ArgumentError => e
    #   if block_given?
    #     # TRANSLATORS, do not translate this string - it is an issue code
    #     yield('EXPECTED_COLLECTION')
    #   else
    #     raise e
    #   end
    end
  end
  # reuse the split_key parser used also by lookup
  include Puppet::Pops::Lookup::SubLookup
end
