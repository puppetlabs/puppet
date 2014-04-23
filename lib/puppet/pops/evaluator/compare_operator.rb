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

  def initialize
    @@equals_visitor  ||= Puppet::Pops::Visitor.new(self, "equals", 1, 1)
    @@compare_visitor ||= Puppet::Pops::Visitor.new(self, "cmp", 1, 1)
    @@include_visitor ||= Puppet::Pops::Visitor.new(self, "include", 1, 1)
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
  def include?(a, b)
    @@include_visitor.visit_this_1(self, a, b)
  end

  protected

  def cmp_String(a, b)
    # if both are numerics in string form, compare as number
    n1 = Puppet::Pops::Utils.to_n(a)
    n2 = Puppet::Pops::Utils.to_n(b)

    # Numeric is always lexically smaller than a string, even if the string is empty.
    return n1 <=> n2    if n1 && n2
    return -1           if n1 && b.is_a?(String)
    return 1            if n2
    return a.casecmp(b) if b.is_a?(String)

    raise ArgumentError.new("A String is not comparable to a non String or Number")
  end

  # Equality is case independent.
  def equals_String(a, b)
    if n1 = Puppet::Pops::Utils.to_n(a)
      if n2 = Puppet::Pops::Utils.to_n(b)
        n1 == n2
      else
        false
      end
    else
      return false unless b.is_a?(String)
      a.casecmp(b) == 0
    end
  end

  def cmp_Numeric(a, b)
    if n2 = Puppet::Pops::Utils.to_n(b)
      a <=> n2
    elsif b.kind_of?(String)
      # Numeric is always lexiographically smaller than a string, even if the string is empty.
      -1
    else
      raise ArgumentError.new("A Numeric is not comparable to non Numeric or String")
    end
  end

  def equals_Numeric(a, b)
    if n2 = Puppet::Pops::Utils.to_n(b)
      a == n2
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
    b.nil? || b == :undef
  end

  def equals_Symbol(a, b)
    a == b || a == :undef && b.nil?
  end

  def include_Object(a, b)
    false
  end

  def include_String(a, b)
    case b
    when String
      # subsstring search downcased
      a.downcase.include?(b.downcase)
    when Regexp
      # match (convert to boolean)
      !!(a =~ b)
    when Numeric
      # convert string to number, true if ==
      equals(a, b)
    when Puppet::Pops::Types::PStringType
      # is there a string in a string? (yes, each char is a string, and an empty string contains an empty string)
      true
    else
      if b == Puppet::Pops::Types::PDataType || b == Puppet::Pops::Types::PObjectType
        # A String is Data and Object (but not of all subtypes of those types).
        true
      else
        false
      end
    end
  end

  def include_Array(a, b)
    case b
    when Regexp
      a.each do |element|
        next unless element.is_a? String
        return true if element =~ b
      end
      return false
    when Puppet::Pops::Types::PAbstractType
      a.each {|element| return true if @type_calculator.instance?(b, element) }
      return false
    else
      a.each {|element| return true if equals(element, b) }
      return false
    end
  end

  def include_Hash(a, b)
    include?(a.keys, b)
  end
end
