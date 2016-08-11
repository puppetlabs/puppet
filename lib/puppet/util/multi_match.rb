# MultiMatch allows multiple values to be tested at once in a case expression.
# This class is needed since Array does not implement the === operator to mean
# "each v === other.each v". 
#
# This class is useful in situations when the Puppet Type System cannot be used
# (e.g. in Logging, since it needs to be able to log very early in the initialization
# cycle of puppet)
#
# Typically used with the constants
# NOT_NIL
# TUPLE
# TRIPLE
# 
# which test against single NOT_NIL value, Array with two NOT_NIL, and Array with three NOT_NIL
#
module Puppet::Util
class MultiMatch
  attr_reader :values

  def initialize(*values)
    @values = values
  end

  def ===(other)
    lv = @values  # local var is faster than instance var
    case other
    when MultiMatch
      return false unless other.values.size == values.size
      other.values.each_with_index {|v, i| return false unless lv[i] === v || v === lv[i]}
    when Array
      return false unless other.size == values.size
      other.each_with_index {|v, i| return false unless lv[i] === v || v === lv[i]}
    else
      false
    end
    true
  end

  # Matches any value that is not nil using the === operator.
  #
  class MatchNotNil
    def ===(v)
      !v.nil?
    end
  end

  NOT_NIL = MatchNotNil.new().freeze
  TUPLE = MultiMatch.new(NOT_NIL, NOT_NIL).freeze
  TRIPLE = MultiMatch.new(NOT_NIL, NOT_NIL, NOT_NIL).freeze
end
end
