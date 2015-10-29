require 'puppet/indirector/none'

class Puppet::DataBinding::None < Puppet::Indirector::None
  desc "A Dummy terminus that always throws :no_such_key for data lookups."
  def find(request)
    throw :no_such_key
  end
end
