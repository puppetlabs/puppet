require 'puppet/node/inventory'
require 'puppet/indirector/yaml'

class Puppet::Node::Inventory::Yaml < Puppet::Indirector::Yaml
  desc "Return node names matching the fact query"

  # Return the path to a given node's file.
  def yaml_dir_path
    base = Puppet.run_mode.master? ? Puppet[:yamldir] : Puppet[:clientyamldir]
    File.join(base, 'facts', '*.yaml')
  end

  def node_matches?(facts, options)
    options.each do |key, value|
      type, name, operator = key.to_s.split(".")
      operator ||= 'eq'

      next unless type == "facts"
      return false unless facts.values[name]

      return false unless case operator
      when "eq"
        facts.values[name].to_s == value.to_s
      when "le"
        facts.values[name].to_f <= value.to_f
      when "ge"
        facts.values[name].to_f >= value.to_f
      when "lt"
        facts.values[name].to_f < value.to_f
      when "gt"
        facts.values[name].to_f > value.to_f
      when "ne"
        facts.values[name].to_s != value.to_s
      end
    end
    return true
  end

  def search(request)
    node_names = []
    Dir.glob(yaml_dir_path).each do |file|
      facts = YAML.load_file(file)
      node_names << facts.name if node_matches?(facts, request.options)
    end
    node_names
  end
end
