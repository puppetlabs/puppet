require 'puppet/node/facts'
require 'puppet/indirector/json'
require 'puppet/indirector/fact_search'

class Puppet::Node::Facts::Json < Puppet::Indirector::JSON
  desc "Store client facts as flat files, serialized using JSON, or
    return deserialized facts from disk."

  include Puppet::Indirector::FactSearch
  
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

  def json_dir_path
    self.path("*")
  end
end
