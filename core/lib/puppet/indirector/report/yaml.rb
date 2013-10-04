require 'puppet/transaction/report'
require 'puppet/indirector/yaml'

class Puppet::Transaction::Report::Yaml < Puppet::Indirector::Yaml
  desc "Store last report as a flat file, serialized using YAML."

  # Force report to be saved there
  def path(name,ext='.yaml')
    Puppet[:lastrunreport]
  end
end
