require 'puppet/resource/catalog'
require 'puppet/indirector/marshal'

class Puppet::Resource::Catalog::Marshal < Puppet::Indirector::Marshal
  desc "Store catalogs as flat files, serialized using Marshal."

  private

  # Override these, because yaml doesn't want to convert our self-referential
  # objects.  This is hackish, but eh.
  def from_marshal(text)
    if config = Marshal.load(text)
      return config
    end
  end

  def to_marshal(config)
    # We can't yaml-dump classes.
    #config.edgelist_class = nil
    Marshal.dump(config)
  end
end
