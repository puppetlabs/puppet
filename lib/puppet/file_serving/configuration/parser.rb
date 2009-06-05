require 'puppet/file_serving/configuration'
require 'puppet/util/loadedfile'

class Puppet::FileServing::Configuration::Parser < Puppet::Util::LoadedFile
    Mount = Puppet::FileServing::Mount
    MODULES = 'modules'

    # Parse our configuration file.
    def parse
        raise("File server configuration %s does not exist" % self.file) unless FileTest.exists?(self.file)
        raise("Cannot read file server configuration %s" % self.file) unless FileTest.readable?(self.file)

        @mounts = {}
        @count = 0

        File.open(self.file) { |f|
            mount = nil
            f.each { |line|
                # Have the count increment at the top, in case we throw exceptions.
                @count += 1

                case line
                when /^\s*#/; next # skip comments
                when /^\s*$/; next # skip blank lines
                when /\[([-\w]+)\]/
                    mount = newmount($1)
                when /^\s*(\w+)\s+(.+)$/
                    var = $1
                    value = $2
                    raise(ArgumentError, "Fileserver configuration file does not use '=' as a separator") if value =~ /^=/
                    case var
                    when "path"
                        path(mount, value)
                    when "allow"
                        allow(mount, value)
                    when "deny"
                        deny(mount, value)
                    else
                        raise ArgumentError.new("Invalid argument '%s'" % var,
                            @count, file)
                    end
                else
                    raise ArgumentError.new("Invalid line '%s'" % line.chomp,
                        @count, file)
                end
            }
        }

        validate()

        return @mounts
    end

    private

    # Allow a given pattern access to a mount.
    def allow(mount, value)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        x = value.split(/\s*,\s*/).each { |val|
            begin
                mount.info "allowing %s access" % val
                mount.allow(val)
            rescue AuthStoreError => detail
                raise ArgumentError.new(detail.to_s,
                    @count, file)
            end
        }
    end

    # Deny a given pattern access to a mount.
    def deny(mount, value)
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
        x = value.split(/\s*,\s*/).each { |val|
            begin
                mount.info "denying %s access" % val
                mount.deny(val)
            rescue AuthStoreError => detail
                raise ArgumentError.new(detail.to_s,
                    @count, file)
            end
        }
    end

    # Create a new mount.
    def newmount(name)
        if @mounts.include?(name)
            raise ArgumentError, "%s is already mounted at %s" %
                [@mounts[name], name], @count, file
        end
        case name
        when "modules"
            mount = Mount::Modules.new(name)
        when "plugins"
            mount = Mount::Plugins.new(name)
        else
            mount = Mount::File.new(name)
        end
        @mounts[name] = mount
        return mount
    end

    # Set the path for a mount.
    def path(mount, value)
        if mount.respond_to?(:path=)
            begin
                mount.path = value
            rescue ArgumentError => detail
                Puppet.err "Removing mount %s: %s" % [mount.name, detail]
                @mounts.delete(mount.name)
            end
        else
            Puppet.warning "The '#{mount.name}' module can not have a path. Ignoring attempt to set it"
        end
    end

    # Make sure all of our mounts are valid.  We have to do this after the fact
    # because details are added over time as the file is parsed.
    def validate
        @mounts.each { |name, mount| mount.validate }
    end
end
