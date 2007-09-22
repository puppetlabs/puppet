Puppet::Util::SettingsStore.newstore(:rest) do
    desc "Store client configurations via a REST web service."

    require 'net/http'
 
    # Get a client's config. (called in collector?)
    def get(client, config)
        # Assuming this comes in as Puppet::Parser objects
        # we may need way to choose which transport data type we use.
       
        # hmm.. is this even useful for stored configs? I suppose there could
        # be scenarios where it'd be cool, like ralsh or something.
    end

    def initialize
        @host = Puppet[:puppetstorehost]
        @port = Puppet[:puppetstoreport]

	# Not sure if this is bad idea to share.
        @http = Net::HTTP.new(@host, @port)
    end

    # Store config to the web service. (called in getconfig?)
    def store(client, config)
        # Probably store as yaml...
        puppetstore = Thread.new do
            benchmark(:notice, "Stored configuration for %s" % client) do
                begin
		    # config should come from elsewhere; probably in getconfig I assume.
                    # should probably allow a config option for the serialization type.
                    yaml = YAML.dump(config)
                    url = "/collector/create"
                    @http.post(url, yaml, { 'Content-Type' => 'text/yaml' })
                rescue => detail
                    Puppet.err("ERROR: storeconfig failed: ", detail.to_s)
                end
            end
        end
        puppetstore.run
    end

    # Rough first try... assuming the calling method handles the data type conversion
    # Can we use a thread here? Probably needs to be the caller's thread.
    def collect_exported(client, conditions)
        begin
            # Gotta be a better way... seems goofy to me.
            # maybe using a nested rails rest route...
           
            # filterhost so we don't get exported resources for the current client
            url = "/resources?restype=exported&filterhost=#{client}"
            conditions.each_pair {|k,v| url << "&#{k}=#{v}"}
            res = @http.get(url)
        rescue => detail
            Puppet.err("ERROR: collect_exported failed: ", detail.to_s)
        end

        return res.body unless !res.is_a?(Net::HTTPOK)
    end

end
