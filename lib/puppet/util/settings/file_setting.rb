require 'puppet/util/settings/setting'

# A file.
class Puppet::Util::Settings::FileSetting < Puppet::Util::Settings::Setting
    attr_writer :owner, :group
    attr_accessor :mode, :create

    # Should we create files, rather than just directories?
    def create_files?
        create
    end

    def group
        if defined? @group
            return @settings.convert(@group)
        else
            return nil
        end
    end

    def owner
        if defined? @owner
            return @settings.convert(@owner)
        else
            return nil
        end
    end

    # Set the type appropriately.  Yep, a hack.  This supports either naming
    # the variable 'dir', or adding a slash at the end.
    def munge(value)
        # If it's not a fully qualified path...
        if value.is_a?(String) and value !~ /^\$/ and value !~ /^\// and value != 'false'
            # Make it one
            value = File.join(Dir.getwd, value)
        end
        if value.to_s =~ /\/$/
            @type = :directory
            return value.sub(/\/$/, '')
        end
        return value
    end

    # Return the appropriate type.
    def type
        value = @settings.value(self.name)
        if @name.to_s =~ /dir/
            return :directory
        elsif value.to_s =~ /\/$/
            return :directory
        elsif value.is_a? String
            return :file
        else
            return nil
        end
    end

    # Turn our setting thing into a Puppet::Resource instance.
    def to_resource
        return nil unless type = self.type

        path = self.value

        return nil unless path.is_a?(String)

        # Make sure the paths are fully qualified.
        path = File.join(Dir.getwd, path) unless path =~ /^\//

        return nil unless type == :directory or create_files? or File.exist?(path)
        return nil if path =~ /^\/dev/

        resource = Puppet::Resource.new(:file, path)
        resource[:mode] = self.mode if self.mode

        if Puppet.features.root?
            resource[:owner] = self.owner if self.owner
            resource[:group] = self.group if self.group
        end

        resource[:ensure] = type
        resource[:loglevel] = :debug
        resource[:backup] = false

        resource.tag(self.section, self.name, "settings")

        resource
    end

    # Make sure any provided variables look up to something.
    def validate(value)
        return true unless value.is_a? String
        value.scan(/\$(\w+)/) { |name|
            name = $1
            unless @settings.include?(name)
                raise ArgumentError,
                    "Settings parameter '%s' is undefined" %
                    name
            end
        }
    end
end

