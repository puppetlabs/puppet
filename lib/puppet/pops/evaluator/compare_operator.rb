module Puppet::Pops
module Evaluator
# Compares the puppet DSL way
#
# ==Equality
# All string vs. numeric equalities check for numeric equality first, then string equality
# Arrays are equal to arrays if they have the same length, and each element #equals
# Hashes  are equal to hashes if they have the same size and keys and values #equals.
# All other objects are equal if they are ruby #== equal
#
class CompareOperator
  include Utils

  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Runtime3Support

  def initialize
    @@equals_visitor  ||= Visitor.new(self, "equals", 1, 1)
    @@compare_visitor ||= Visitor.new(self, "cmp", 1, 1)
    @@match_visitor ||= Visitor.new(self, "match", 2, 2)
    @@include_visitor ||= Visitor.new(self, "include", 2, 2)
  end

  def equals (a, b)
    @@equals_visitor.visit_this_1(self, a, b)
  end

  # Performs a comparison of a and b, and return > 0 if a is bigger, 0 if equal, and < 0 if b is bigger.
  # Comparison of String vs. Numeric always compares using numeric.
  def compare(a, b)
    @@compare_visitor.visit_this_1(self, a, b)
  end

  # Performs a match of a and b, and returns true if b matches a
  def match(a, b, scope)
    @@match_visitor.visit_this_2(self, b, a, scope)
  end

  # Answers is b included in a
  def include?(a, b, scope)
    @@include_visitor.visit_this_2(self, a, b, scope)
  end

  protected

  def cmp_String(a, b)
    return a.casecmp(b) if b.is_a?(String)
    raise ArgumentError.new("A String is not comparable to a non String")
  end

  # Equality is case independent.
  def equals_String(a, b)
    return false unless b.is_a?(String)
    a.casecmp(b) == 0
  end

  def cmp_Numeric(a, b)
    if b.is_a?(Numeric)
      a <=> b
    else
      raise ArgumentError.new("A Numeric is not comparable to non Numeric")
    end
  end

  def equals_Numeric(a, b)
    if b.is_a?(Numeric)
      a == b
    else
      false
    end
  end

  def equals_Array(a, b)
    return false unless b.is_a?(Array) && a.size == b.size
    a.each_index {|i| return false unless equals(a.slice(i), b.slice(i)) }
    true
  end

  def equals_Hash(a, b)
    return false unless b.is_a?(Hash) && a.size == b.size
    a.each {|ak, av| return false unless equals(b[ak], av)}
    true
  end

  def cmp_Symbol(a, b)
    if b.is_a?(Symbol)
      a <=> b
    else
      raise ArgumentError.new("Symbol not comparable to non Symbol")
    end
  end

  def cmp_Version(a, b)
    raise ArgumentError.new('Versions not comparable to non Versions') unless b.is_a?(Semantic::Version)
    a <=> b
  end

  def cmp_Object(a, b)
    raise ArgumentError.new('Only Strings, Numbers, and Versions are comparable')
  end


  def equals_Object(a, b)
    a == b
  end

  def equals_NilClass(a, b)
    # :undef supported in case it is passed from a 3x data structure
    b.nil? || b == :undef
  end

  def equals_Symbol(a, b)
    # :undef supported in case it is passed from a 3x data structure
    a == b || a == :undef && b.nil?
  end

  def include_Object(a, b, scope)
    false
  end

  def include_String(a, b, scope)
    case b
    when String
      # subsstring search downcased
      a.downcase.include?(b.downcase)
    when Regexp
      matched = a.match(b)           # nil, or MatchData
      set_match_data(matched, scope) # creates ephemeral
      !!matched                      # match (convert to boolean)
    when Numeric
      # convert string to number, true if ==
      equals(a, b)
    else
      false
    end
  end

  def include_Array(a, b, scope)
    case b
    when Regexp
      matched = nil
      a.each do |element|
        next unless element.is_a? String
        matched = element.match(b) # nil, or MatchData
        break if matched
      end
      # Always set match data, a "not found" should not keep old match data visible
      set_match_data(matched, scope) # creates ephemeral
      return !!matched
    when String, Semantic::Version
      a.any? { |element| match(b, element, scope) }
    when Types::PAnyType
      a.each {|element| return true if b.instance?(element) }
      return false
    else
      a.each {|element| return true if equals(element, b) }
      return false
    end
  end

  def include_Hash(a, b, scope)
    include?(a.keys, b, scope)
  end

  def include_VersionRange(a, b, scope)
    Types::PSemVerRangeType.include?(a, b)
  end

  # Matches in general by using == operator
  def match_Object(pattern, a, scope)
    equals(a, pattern)
  end

  # Matches only against strings
  def match_Regexp(regexp, left, scope)
    return false unless left.is_a? String
    matched = regexp.match(left)
    set_match_data(matched, scope) # creates or clears ephemeral
    !!matched # convert to boolean
  end

  # Matches against semvers and strings
  def match_Version(version, left, scope)
    if left.is_a?(Semantic::Version)
      version == left
    elsif left.is_a? String
      begin
        version == Semantic::Version.parse(left)
      rescue ArgumentError
        false
      end
    else
      false
    end
  end

  # Matches against semvers and strings
  def match_VersionRange(range, left, scope)
    Types::PSemVerRangeType.include?(range, left)
  end

  def match_PAnyType(any_type, left, scope)
    # right is a type and left is not - check if left is an instance of the given type
    # (The reverse is not terribly meaningful - computing which of the case options that first produces
    # an instance of a given type).
    #
    any_type.instance?(left)
  end

  def match_Array(array, left, scope)
    return false unless left.is_a?(Array)
    return false unless left.length == array.length
    array.each_with_index.all? { | pattern, index| match(left[index], pattern, scope) }
  end

  def match_Hash(hash, left, scope)
    return false unless left.is_a?(Hash)
    hash.all? {|x,y| match(left[x], y, scope) }
  end

  def match_Symbol(symbol, left, scope)
    return true if symbol == :default
    equals(left, default, scope)
  end
end
end
end
