# utility module for catalog comparison
module PuppetSpec::Catalog
  class Puppet::Resource::Catalog

    # compares compiled catalogs
    def ==(other)
      [:name, :environment, :tags,
       :resources, :edges, :classes].map do |m|
        self.send(m) == other.send(m)
      end.all?
    end
  end

  class Puppet::Relationship

    # compares relationships
    def ==(other)
      return true if other.is_a? String 
      [:source, :target, :event, :callback].map do |m|
        self.send(m) == other.send(m)
      end.all?
    end
  end

end

