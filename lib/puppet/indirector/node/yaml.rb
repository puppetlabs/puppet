require 'puppet/node'
require 'puppet/indirector/yaml'

class Puppet::Node::Yaml < Puppet::Indirector::Yaml
  desc "Store node information as flat files, serialized using YAML,
    or deserialize stored YAML nodes."

  protected

  def fix(object)
    # This looks very strange because when the object is read from disk the
    # environment is a string and by assigning it back onto the object it gets
    # converted to a Puppet::Node::Environment.
    #
    # The Puppet::Node class can't handle this itself because we are loading
    # with just straight YAML, which doesn't give the object a chance to modify
    # things as it is loaded. Instead YAML simply sets the instance variable
    # and leaves it at that.
    object.environment = object.environment
    object
  end
end
