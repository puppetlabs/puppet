# utility module for catalog comparison
module PuppetSpec::Catalog
  class Puppet::Resource::Catalog

    # compares compiled catalogs
    def ==(other)
      [
        :name,
        :environment,
        :tags,
        :resources,
        :edges,
        :classes
      ].map do |m|
        self_results  = self.send  m
        other_results = other.send m
        self_results  = self_results.sort  if self_results.respond_to?  :sort
        other_results = other_results.sort if other_results.respond_to? :sort
        self_results == other_results
      end.all?
    end
  end

  class Puppet::Resource
    def <=>(other)
      self.name <=> other.name
    end
  end

  class Puppet::Relationship
    def <=>(other)
      self.to_s <=> other.to_s
    end

    # compares relationships
    def ==(other)
      if other.is_a? String
        # this happens when loading from YAML
        self.to_s == other
      else
        [:source, :target, :event, :callback].map do |m|
          self.send(m) == other.send(m)
        end.all?
      end
    end
  end

end

