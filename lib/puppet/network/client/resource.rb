# The client for interacting with remote Puppet agents to query and modify
# remote system state.
class Puppet::Network::Client::Resource < Puppet::Network::Client
    def apply(bucket)
        case bucket
        when Puppet::TransObject
            tmp = Puppet::TransBucket.new
            tmp.push bucket
            bucket = tmp
            bucket.name = Facter["hostname"].value
            bucket.type = "resource"
        when Puppet::TransBucket
            # nothing
        else
            raise Puppet::DevError, "You must pass a transportable object, not a %s" %
                bucket.class
        end

        unless @local
            bucket = Base64.encode64(YAML::dump(bucket))
        end
        report = @driver.apply(bucket, "yaml")

        return report
    end

    def describe(type, name, retrieve = false, ignore = false)
        Puppet.info "Describing %s[%s]" % [type.to_s.capitalize, name]
        text = @driver.describe(type, name, retrieve, ignore, "yaml")

        object = nil
        if @local
            object = text
        else
            object = YAML::load(Base64.decode64(text))
        end

        return object
    end

    def list(type, ignore = false, base = false)
        bucket = @driver.list(type, ignore, base, "yaml")

        unless @local
            bucket = YAML::load(Base64.decode64(bucket))
        end

        return bucket
    end
end

# $Id$
