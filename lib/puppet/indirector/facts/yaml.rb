# frozen_string_literal: true

require_relative '../../../puppet/node/facts'
require_relative '../../../puppet/indirector/yaml'
require_relative '../../../puppet/indirector/fact_search'

class Puppet::Node::Facts::Yaml < Puppet::Indirector::Yaml
  desc "Store client facts as flat files, serialized using YAML, or
    return deserialized facts from disk."

  include Puppet::Indirector::FactSearch

  def search(request)
    node_names = []
    Dir.glob(yaml_dir_path).each do |file|
      facts = load_file(file)
      if facts && node_matches?(facts, request.options)
        node_names << facts.name
      end
    end
    node_names
  end

  private

  # Return the path to a given node's file.
  def yaml_dir_path
    base = Puppet.run_mode.server? ? Puppet[:yamldir] : Puppet[:clientyamldir]
    File.join(base, 'facts', '*.yaml')
  end
end
