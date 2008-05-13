#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/file_serving'
require 'puppet/file_serving/mount'
require 'puppet/util/cacher'

class Puppet::FileServing::Configuration
    require 'puppet/file_serving/configuration/parser'

    extend Puppet::Util::Cacher

    @config_fileuration = nil

    Mount = Puppet::FileServing::Mount

    # Create our singleton configuration.
    def self.create
        attr_cache(:configuration) { new() }
    end

    private_class_method  :new

    # Verify that the client is allowed access to this file.
    def authorized?(file, options = {})
        mount, file_path = split_path(file, options[:node])
        # If we're not serving this mount, then access is denied.
        return false unless mount
        return mount.allowed?(options[:node], options[:ipaddress])
    end

    # Search for a file.
    def file_path(key, options = {})
        mount, file_path = split_path(key, options[:node])

        return nil unless mount

        # The mount checks to see if the file exists, and returns nil
        # if not.
        return mount.file(file_path, options)
    end

    def initialize
        @mounts = {}
        @config_file = nil

        # We don't check to see if the file is modified the first time,
        # because we always want to parse at first.
        readconfig(false)
    end

    # Is a given mount available?
    def mounted?(name)
        @mounts.include?(name)
    end

    def umount(name)
        @mounts.delete(name) if @mounts.include? name
    end

    private

    # Deal with ignore parameters.
    def handleignore(children, path, ignore)            
        ignore.each { |ignore|                
            Dir.glob(File.join(path,ignore), File::FNM_DOTMATCH) { |match|
                children.delete(File.basename(match))
            }                
        }
        return children
    end  

    # Read the configuration file.
    def readconfig(check = true)
        config = Puppet[:fileserverconfig]

        return unless FileTest.exists?(config)

        @parser ||= Puppet::FileServing::Configuration::Parser.new(config)

        if check and ! @parser.changed?
            return
        end

        # Don't assign the mounts hash until we're sure the parsing succeeded.
        begin
            newmounts = @parser.parse
            @mounts = newmounts
        rescue => detail
            Puppet.err "Error parsing fileserver configuration: %s; using old configuration" % detail
        end
    end

    # Split the path into the separate mount point and path.
    def split_path(uri, node)
        # Reparse the configuration if necessary.
        readconfig

        raise(ArgumentError, "Cannot find file: Invalid path '%s'" % uri) unless uri =~ %r{/([-\w]+)/?}

        # the dir is based on one of the mounts
        # so first retrieve the mount path
        mount = path = nil
        # Strip off the mount name.
        mount_name, path = uri.sub(%r{^/}, '').split(File::Separator, 2)

        return nil unless mount = @mounts[mount_name]

        if path == ""
            path = nil
        elsif path
            # Remove any double slashes that might have occurred
            path = URI.unescape(path.gsub(/\/\//, "/"))
        end

        return mount, path
    end

    def to_s
        "fileserver"
    end
end
