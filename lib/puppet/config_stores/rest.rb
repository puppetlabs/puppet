Puppet::Util::ConfigStore.newstore(:rest) do
    desc "Store client configurations via a REST web service."

    # Get a client's config. (called in collector?)
    def get(client, config)
      # Assuming this come in as Puppet::Parser objects
      # we may need way to choose which transport data type we use.
    end

    def initialize
      # need config vars like puppetstore host, port, etc.
    end

    # Store config to the web service. (called in getconfig?)
    def store(client, config)
      # Probably store as yaml...
    end

end
