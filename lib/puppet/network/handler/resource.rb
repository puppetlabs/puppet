require 'puppet'
require 'puppet/network/handler'

# Serve Puppet elements.  Useful for querying, copying, and, um, other stuff.
class Puppet::Network::Handler
    class Resource < Handler
        desc "An interface for interacting with client-based resources that can
        be used for querying or managing remote machines without using Puppet's
        central server tools.

        The ``describe`` and ``list`` methods return TransBuckets containing
        TransObject instances (``describe`` returns a single TransBucket),
        and the ``apply`` method accepts a TransBucket of TransObjects and
        applies them locally.
        "

        attr_accessor :local

        @interface = XMLRPC::Service::Interface.new("resource") { |iface|
            iface.add_method("string apply(string, string)")
            iface.add_method("string describe(string, string, array, array)")
            iface.add_method("string list(string, array, string)")
        }

        side :client

        # Apply a TransBucket as a transaction.
        def apply(bucket, format = "yaml", client = nil, clientip = nil)
            unless local?
                begin
                    case format
                    when "yaml"
                        bucket = YAML::load(Base64.decode64(bucket))
                    else
                        raise Puppet::Error, "Unsupported format '%s'" % format
                    end
                rescue => detail
                    raise Puppet::Error, "Could not load YAML TransBucket: %s" % detail
                end
            end

            catalog = bucket.to_catalog

            # And then apply the catalog.  This way we're reusing all
            # the code in there.  It should probably just be separated out, though.
            transaction = catalog.apply

            # And then clean up
            catalog.clear(true)

            # It'd be nice to return some kind of report, but... at this point
            # we have no such facility.
            return "success"
        end

        # Describe a given object.  This returns the 'is' values for every property
        # available on the object type.
        def describe(type, name, retrieve = nil, ignore = [], format = "yaml", client = nil, clientip = nil)
            Puppet.info "Describing %s[%s]" % [type.to_s.capitalize, name]
            @local = true unless client
            typeklass = nil
            unless typeklass = Puppet::Type.type(type)
                raise Puppet::Error, "Puppet type %s is unsupported" % type
            end

            obj = nil

            retrieve ||= :all
            ignore ||= []

            begin
                obj = typeklass.create(:name => name, :check => retrieve)
            rescue Puppet::Error => detail
                raise Puppet::Error, "%s[%s] could not be created: %s" %
                    [type, name, detail]
            end

            unless obj
                raise XMLRPC::FaultException.new(
                    1, "Could not create %s[%s]" % [type, name]
                )
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

            unless @local
                case format
                when "yaml"
                    trans = Base64.encode64(YAML::dump(trans))
                else
                    raise XMLRPC::FaultException.new(
                        1, "Unavailable config format %s" % format
                    )
                end
            end

            return trans
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
        def list(type, ignore = [], base = nil, format = "yaml", client = nil, clientip = nil)
            @local = true unless client
            typeklass = nil
            unless typeklass = Puppet::Type.type(type)
                raise Puppet::Error, "Puppet type %s is unsupported" % type
            end

            # They can pass in false
            ignore ||= []
            ignore = [ignore] unless ignore.is_a? Array
            bucket = Puppet::TransBucket.new
            bucket.type = typeklass.name

            typeklass.instances.each do |obj|
                next if ignore.include? obj.name

                #object = Puppet::TransObject.new(obj.name, typeklass.name)
                bucket << obj.to_trans
            end

            unless @local
                case format
                when "yaml"
                    begin
                    bucket = Base64.encode64(YAML::dump(bucket))
                    rescue => detail
                        Puppet.err detail
                        raise XMLRPC::FaultException.new(
                            1, detail.to_s
                        )
                    end
                else
                    raise XMLRPC::FaultException.new(
                        1, "Unavailable config format %s" % format
                    )
                end
            end

            return bucket
        end

        private

        def authcheck(file, mount, client, clientip)
            unless mount.allowed?(client, clientip)
                mount.warning "%s cannot access %s" %
                    [client, file]
                raise Puppet::AuthorizationError, "Cannot access %s" % mount
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
            "resource"
        end
    end
end

