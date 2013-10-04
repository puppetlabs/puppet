require 'puppet/run'
require 'puppet/indirector/rest'

class Puppet::Run::Rest < Puppet::Indirector::REST
  desc "Trigger Agent runs via REST."

  private

  def deserialize_save(content_type, body)
    model.convert_from(content_type, body)
  end
end
