# utility module for catalog comparison
module PuppetSpec::Catalog
  class Puppet::Resource::Catalog

    # compares compiled catalogs
    def ==(other)
      [:name, :version, :environment, :tags,
       :resources, :edges, :classes].map do |m|
        self.send(m) == other.send(m)
      end.all?
    end
  end

  class Puppet::Relationship

    # compares relationships
    def ==(other)
      [:source, :target, :event, :callback].map do |m|
        self.send(m) == other.send(m)
      end.all?
    end
  end

end

