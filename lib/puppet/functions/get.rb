# Digs into a value with dot notation to get a value from within a structure.
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
# @example Navigating into a value
# ```puppet
# #get($facts, 'os.family')
# $facts.get('os.family')
# ```
# Would both result in the value of $facts['os']['family']
#
# @example Getting the value from an expression
# ```puppet
# get([1,2,[{'name' =>'waldo'}]], '2.0.name')
# ```
# Would result in 'waldo'
#
# @example Using a default value
# ```puppet
# get([1,2,[{'name' =>'waldo'}]], '2.1.name', 'not waldo')
#
# ```
# Would result in 'not waldo'
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
# Also see:
# * `getvar()` that takes the first segment to be the name of a variable
#   and then delegates to this function.
# * `dig()` function which is similar but uses an
#   array of navigation values instead of a dot notation string.
#
# @since 6.0.0
#
Puppet::Functions.create_function(:get, Puppet::Functions::InternalFunction) do
  dispatch :get_from_value do
    param 'Any', :value
    param 'String', :dotted_string
    optional_param 'Any', :default_value
    optional_block_param 'Callable[1,1]', :block
  end

  # Gets a result from given value and a navigation string
  #
  def get_from_value(value, navigation, default_value = nil, &block)
    return default_value if value.nil?
    return value if navigation.empty?

    # Note: split_key always processes the initial segment as a string even if it could be an integer.
    # This since it is designed for lookup keys. For a numeric first segment
    # like '0.1' the wanted result is [0,1], not ["0", 1]. The workaround here is to
    # prefix the navigation with "x." thus giving split_key a first segment that is a string.
    # The fake segment is then dropped.
    segments = split_key("x." + navigation) {|err| _("Syntax error in dotted-navigation string")}
    segments.shift

    begin
      result = call_function('dig', value, *segments)
      return result.nil? ? default_value : result
    rescue Puppet::ErrorWithData => e
      if block_given?
        yield(e.error_data)
      else
        raise e
      end
    end
  end
  # reuse the split_key parser used also by lookup
  include Puppet::Pops::Lookup::SubLookup
end
