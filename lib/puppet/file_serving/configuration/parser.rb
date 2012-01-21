require 'puppet/file_serving/configuration'
require 'puppet/util/loadedfile'

class Puppet::FileServing::Configuration::Parser < Puppet::Util::LoadedFile
  Mount = Puppet::FileServing::Mount
  MODULES = 'modules'

  # Parse our configuration file.
  def parse
    raise("File server configuration #{self.file} does not exist") unless FileTest.exists?(self.file)
    raise("Cannot read file server configuration #{self.file}") unless FileTest.readable?(self.file)

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
        when /^\s*(\w+)\s+(.+?)(\s*#.*)?$/
          var = $1
          value = $2
          value.strip!
          raise(ArgumentError, "Fileserver configuration file does not use '=' as a separator") if value =~ /^=/
          case var
          when "path"
            path(mount, value)
          when "allow"
            allow(mount, value)
          when "deny"
            deny(mount, value)
          else
            raise ArgumentError.new("Invalid argument '#{var}'", @count, file)
          end
        else
          raise ArgumentError.new("Invalid line '#{line.chomp}'", @count, file)
        end
      }
    }

    validate

    @mounts
  end

  private

  # Allow a given pattern access to a mount.
  def allow(mount, value)
    # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
    x = value.split(/\s*,\s*/).each { |val|
      begin
        mount.info "allowing #{val} access"
        mount.allow(val)
      rescue Puppet::AuthStoreError => detail
        raise ArgumentError.new(detail.to_s, @count, file)
      end
    }
  end

  # Deny a given pattern access to a mount.
  def deny(mount, value)
    # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
    x = value.split(/\s*,\s*/).each { |val|
      begin
        mount.info "denying #{val} access"
        mount.deny(val)
      rescue Puppet::AuthStoreError => detail
        raise ArgumentError.new(detail.to_s, @count, file)
      end
    }
  end

  # Create a new mount.
  def newmount(name)
    raise ArgumentError, "#{@mounts[name]} is already mounted at #{name}", @count, file if @mounts.include?(name)
    case name
    when "modules"
      mount = Mount::Modules.new(name)
    when "plugins"
      mount = Mount::Plugins.new(name)
    else
      mount = Mount::File.new(name)
    end
    @mounts[name] = mount
    mount
  end

  # Set the path for a mount.
  def path(mount, value)
    if mount.respond_to?(:path=)
      begin
        mount.path = value
      rescue ArgumentError => detail
        Puppet.err "Removing mount #{mount.name}: #{detail}"
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
