# Matches a regular expression against a string and returns an array containing the match
# and any matched capturing groups.
#
# The first argument is a string or array of strings. The second argument is either a
# regular expression, regular expression represented as a string, or Regex or Pattern
# data type that the function matches against the first argument.
#
# The returned array contains the entire match at index 0, and each captured group at
# subsequent index values. If the value or expression being matched is an array, the
# function returns an array with mapped match results.
#
# If the function doesn't find a match, it returns 'undef'.
#
# @example Matching a regular expression in a string
#
# ~~~ ruby
# $matches = "abc123".match(/[a-z]+[1-9]+/)
# # $matches contains [abc123]
# ~~~
#
# @example Matching a regular expressions with grouping captures in a string
#
# ~~~ ruby
# $matches = "abc123".match(/([a-z]+)([1-9]+)/)
# # $matches contains [abc123, abc, 123]
# ~~~
#
# @example Matching a regular expression with grouping captures in an array of strings
#
# ~~~ ruby
# $matches = ["abc123","def456"].match(/([a-z]+)([1-9]+)/)
# # $matches contains [[abc123, abc, 123], [def456, def, 456]]
# ~~~
#
# @since 4.0.0
#
Puppet::Functions.create_function(:match) do
  dispatch :match do
    param 'String', :string
    param 'Variant[Any, Type]', :pattern
  end

  dispatch :enumerable_match do
    param 'Array[String]', :string
    param 'Variant[Any, Type]', :pattern
  end

  def initialize(closure_scope, loader)
    super

    # Make this visitor shared among all instantiations of this function since it is faster.
    # This can be used because it is not possible to replace
    # a puppet runtime (where this function is) without a reboot. If you model a function in a module after
    # this class, use a regular instance variable instead to enable reloading of the module without reboot
    #
    @@match_visitor   ||= Puppet::Pops::Visitor.new(self, "match", 1, 1)
  end

  # Matches given string against given pattern and returns an Array with matches.
  # @param string [String] the string to match
  # @param pattern [String, Regexp, Puppet::Pops::Types::PPatternType, Puppet::Pops::PRegexpType, Array] the pattern
  # @return [Array<String>] matches where first match is the entire match, and index 1-n are captures from left to right
  #
  def match(string, pattern)
    @@match_visitor.visit_this_1(self, pattern, string)
  end

  # Matches given Array[String] against given pattern and returns an Array with mapped match results.
  #
  # @param array [Array<String>] the array of strings to match
  # @param pattern [String, Regexp, Puppet::Pops::Types::PPatternType, Puppet::Pops::PRegexpType, Array] the pattern
  # @return [Array<Array<String, nil>>] Array with matches (see {#match}), non matching entries produce a nil entry
  #
  def enumerable_match(array, pattern)
    array.map {|s| match(s, pattern) }
  end

  protected

  def match_Object(obj, s)
    msg = "match() expects pattern of T, where T is String, Regexp, Regexp[r], Pattern[p], or Array[T]. Got #{obj.class}"
    raise ArgumentError, msg
  end

  def match_String(pattern_string, s)
    do_match(s, Regexp.new(pattern_string))
  end

  def match_Regexp(regexp, s)
    do_match(s, regexp)
  end

  def match_PRegexpType(regexp_t, s)
    raise ArgumentError, "Given Regexp Type has no regular expression" unless regexp_t.pattern
    do_match(s, regexp_t.regexp)
  end

  def match_PPatternType(pattern_t, s)
    # Since we want the actual match result (not just a boolean), an iteration over
    # Pattern's regular expressions is needed. (They are of PRegexpType)
    result = nil
    pattern_t.patterns.find {|pattern| result = match(s, pattern) }
    result
  end

  # Returns the first matching entry
  def match_Array(array, s)
    result = nil
    array.flatten.find {|entry| result = match(s, entry) }
    result
  end

  private

  def do_match(s, regexp)
    if result = regexp.match(s)
      result.to_a
    end
  end
end
