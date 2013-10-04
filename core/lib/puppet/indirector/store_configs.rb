class Puppet::Indirector::StoreConfigs < Puppet::Indirector::Terminus
  def initialize
    super
    # This will raise if the indirection can't be found, so we can assume it
    # is always set to a valid instance from here on in.
    @target = indirection.terminus Puppet[:storeconfigs_backend]
  end

  attr_reader :target

  def head(request)
    target.head request
  end

  def find(request)
    target.find request
  end

  def search(request)
    target.search request
  end

  def save(request)
    target.save request
  end

  def destroy(request)
    target.save request
  end
end
