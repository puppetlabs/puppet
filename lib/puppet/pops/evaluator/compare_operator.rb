# Compares the puppet DSL way
#
# ==Equality
# All string vs. numeric equalities check for numeric equality first, then string equality
# Arrays are equal to arrays if they have the same length, and each element #equals
# Hashes  are equal to hashes if they have the same size and keys and values #equals.
# All other objects are equal if they are ruby #== equal
#
class Puppet::Pops::Evaluator::CompareOperator
  include Puppet::Pops::Utils

  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support

  def initialize
    @@equals_visitor  ||= Puppet::Pops::Visitor.new(self, "equals", 1, 1)
    @@compare_visitor ||= Puppet::Pops::Visitor.new(self, "cmp", 1, 1)
    @@include_visitor ||= Puppet::Pops::Visitor.new(self, "include", 2, 2)
    @type_calculator = Puppet::Pops::Types::TypeCalculator.new()
  end

  def equals (a, b)
    @@equals_visitor.visit_this_1(self, a, b)
  end

  # Performs a comparison of a and b, and return > 0 if a is bigger, 0 if equal, and < 0 if b is bigger.
  # Comparison of String vs. Numeric always compares using numeric.
  def compare(a, b)
    @@compare_visitor.visit_this_1(self, a, b)
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

  def cmp_Object(a, b)
    raise ArgumentError.new("Only Strings and Numbers are comparable")
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
    when Puppet::Pops::Types::PAnyType
      a.each {|element| return true if @type_calculator.instance?(b, element) }
      return false
    else
      a.each {|element| return true if equals(element, b) }
      return false
    end
  end

  def include_Hash(a, b, scope)
    include?(a.keys, b, scope)
  end
end
