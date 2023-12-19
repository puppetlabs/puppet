# frozen_string_literal: true

require_relative '../../../puppet/resource/catalog'
require_relative '../../../puppet/indirector/yaml'

class Puppet::Resource::Catalog::Yaml < Puppet::Indirector::Yaml
  desc "Store catalogs as flat files, serialized using YAML."
end
