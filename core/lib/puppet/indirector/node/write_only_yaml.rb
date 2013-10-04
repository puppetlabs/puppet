require 'puppet/node'
require 'puppet/indirector/yaml'

# This is a WriteOnlyYaml terminus that exists only for the purpose of being able to write
# node cache data that later can be read by the YAML terminus.
# The use case this supports is to make it possible to search among the "current nodes"
# when Puppet DB (recommended) or other central storage of information is not available.
#
# @see puppet issue 16753
# @see Puppet::Application::Master#setup_node_cache
# @api private
#
class Puppet::Node::WriteOnlyYaml < Puppet::Indirector::Yaml
  desc "Store node information as flat files, serialized using YAML,
    does not deserialize (write only)."

  # Overridden to always return nil. This is a write only terminus.
  # @param [Object] request Ignored.
  # @return [nil] This implementation always return nil'
  # @api public
  def find(request)
    nil
  end

  # Overridden to always return nil. This is a write only terminus.
  # @param [Object] request Ignored.
  # @return [nil] This implementation always return nil
  # @api public
  def search(request)
    nil
  end
end
