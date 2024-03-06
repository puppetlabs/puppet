# frozen_string_literal: true

# module containing common methods used by json and yaml facts indirection terminus
module Puppet::Indirector::FactSearch
  def node_matches?(facts, options)
    options.each do |key, value|
      type, name, operator = key.to_s.split(".")
      operator ||= 'eq'

      return false unless node_matches_option?(type, name, operator, value, facts)
    end
    true
  end

  def node_matches_option?(type, name, operator, value, facts)
    case type
    when "meta"
      case name
      when "timestamp"
        compare_timestamp(operator, facts.timestamp, Time.parse(value))
      end
    when "facts"
      compare_facts(operator, facts.values[name], value)
    end
  end

  def compare_facts(operator, value1, value2)
    return false unless value1

    case operator
    when "eq"
      value1.to_s == value2.to_s
    when "le"
      value1.to_f <= value2.to_f
    when "ge"
      value1.to_f >= value2.to_f
    when "lt"
      value1.to_f < value2.to_f
    when "gt"
      value1.to_f > value2.to_f
    when "ne"
      value1.to_s != value2.to_s
    end
  end

  def compare_timestamp(operator, value1, value2)
    case operator
    when "eq"
      value1 == value2
    when "le"
      value1 <= value2
    when "ge"
      value1 >= value2
    when "lt"
      value1 < value2
    when "gt"
      value1 > value2
    when "ne"
      value1 != value2
    end
  end
end
