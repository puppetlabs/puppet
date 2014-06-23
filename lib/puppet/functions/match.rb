# Returns the match result of matching a String or Array[String] with one of:
#
# * Regexp
# * String - transformed to a Regexp
# * Pattern type
# * Regexp type
#
# Returns An Array with the entire match at index 0, and each subsequent submatch at index 1-n.
# If there was no match, nil (ie. undef) is returned. If the value to match is an Array, a array
# with mapped match results is returned.
#
# @example matching
#   "abc123".match(/([a-z]+)[1-9]+/)  # => ["abc"]
#   "abc123".match(/([a-z]+)([1-9]+)/)  # => ["abc", "123"]
#
# See the documentation for "The Puppet Type System" for more information about types.
# @since 3.7.0
#
Puppet::Functions.create_function(:match) do
  dispatch :match do
    param 'String', 'string'
    param 'Variant[Any, Type]', 'pattern'
  end

  dispatch :enumerable_match do
    param 'Array[String]', 'string'
    param 'Variant[Any, Type]', 'pattern'
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
