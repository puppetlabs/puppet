require 'puppet'
require 'puppet/server'

module Puppet

# Serve Puppet elements.  Useful for querying, copying, and, um, other stuff.
class Server::PElement < Server::Handler
    attr_accessor :local

    @interface = XMLRPC::Service::Interface.new("pelementserver") { |iface|
        iface.add_method("string describe(string, string, array, array)")
        iface.add_method("string list(string, array, string)")
    }

    # Describe a given object.  This returns the 'is' values for every state
    # available on the object type.
    def describe(type, name, retrieve = nil, ignore = [], format = "yaml", client = nil, clientip = nil)
        @local = true unless client
        typeklass = nil
        unless typeklass = Puppet.type(type)
            raise Puppet::Error, "Puppet type %s is unsupported" % type
        end

        obj = nil

        retrieve ||= :all

        if obj = typeklass[name]
            obj[:check] = retrieve
        else
            begin
                obj = typeklass.create(:name => name, :check => retrieve)
            rescue Puppet::Error => detail
                raise Puppet::Error, "%s[%s] could not be created: %s" %
                    [type, name, detail]
            end
        end

        trans = obj.to_trans

        # Now get rid of any attributes they specifically don't want
        ignore.each do |st|
            if trans.include? st
                trans.delete(st)
            end
        end

        # And get rid of any attributes that are nil
        trans.each do |attr, value|
            if value.nil?
                trans.delete(attr)
            end
        end

        if @local
            return trans
        else
            str = nil
            case format
            when "yaml":
                str = YAML.dump(trans)
            else
                raise XMLRPC::FaultException.new(
                    1, "Unavailable config format %s" % format
                )
            end
            return CGI.escape(str)
        end
    end

    # Create a new fileserving module.
    def initialize(hash = {})
        if hash[:Local]
            @local = hash[:Local]
        else
            @local = false
        end
    end

    # List all of the elements of a given type.
    def list(type, ignore = [], base = nil, client = nil, clientip = nil)
        @local = true unless client
        typeklass = nil
        unless typeklass = Puppet.type(type)
            raise Puppet::Error, "Puppet type %s is unsupported" % type
        end

        ignore = [ignore] unless ignore.is_a? Array
        bucket = TransBucket.new
        bucket.type = typeklass.name

        typeklass.list.each do |obj|
            next if ignore.include? obj.name

            object = TransObject.new(obj.name, typeklass.name)
            bucket << object
        end

        if @local
            return bucket
        else
            str = nil
            case format
            when "yaml":
                str = YAML.dump(bucket)
            else
                raise XMLRPC::FaultException.new(
                    1, "Unavailable config format %s" % format
                )
            end
            return CGI.escape(str)
        end
    end

    private

    def authcheck(file, mount, client, clientip)
        unless mount.allowed?(client, clientip)
            mount.warning "%s cannot access %s" %
                [client, file]
            raise Puppet::Server::AuthorizationError, "Cannot access %s" % mount
        end
    end

    # Deal with ignore parameters.
    def handleignore(children, path, ignore)            
        ignore.each { |ignore|                
            Dir.glob(File.join(path,ignore), File::FNM_DOTMATCH) { |match|
                children.delete(File.basename(match))
            }                
        }
        return children
    end  

    def to_s
        "pelementserver"
    end
end
end

# $Id$
