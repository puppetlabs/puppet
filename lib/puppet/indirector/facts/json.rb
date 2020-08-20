require 'puppet/node/facts'
require 'puppet/indirector/json'

class Puppet::Node::Facts::Json < Puppet::Indirector::JSON
  desc "Store client facts as flat files, serialized using JSON, or
    return deserialized facts from disk."

  def search(request)
    node_names = []
    Dir.glob(json_dir_path).each do |file|
      facts = load_json_from_file(file, '')
      if facts && node_matches?(facts, request.options)
        node_names << facts.name
      end
    end
    node_names
  end

  private

  def node_matches?(facts, options)
    options.each do |key, value|
      type, name, operator = key.to_s.split(".")
      operator ||= 'eq'

      return false unless node_matches_option?(type, name, operator, value, facts)
    end
    return true
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
