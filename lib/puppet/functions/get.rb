# Digs into variable or value with dot notation to get a value from a structure
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
    rescue TypeError => e
      if block_given?
        # TRANSLATORS, do not translate this string - it is an issue code
        yield('EXPECTED_INTEGER_INDEX')
      else
        raise e
      end
    rescue ArgumentError => e
      if block_given?
        # TRANSLATORS, do not translate this string - it is an issue code
        yield('EXPECTED_COLLECTION')
      else
        raise e
      end
    end
  end
  # reuse the split_key parser used also by lookup
  include Puppet::Pops::Lookup::SubLookup
end
