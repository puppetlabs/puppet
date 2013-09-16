module Puppet::Parser::YamlTrimmer
  REMOVE = [:@scope, :@source]

  def to_yaml_properties
    super - REMOVE
  end
end
