#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet'
require 'puppet/file_serving'

class Puppet::FileServing::Configuration

    def self.create(options = {})
        unless defined?(@configuration)
            @configuration = new(options)
        end
        @configuration
    end

    def initialize(options = {})
        if options.include?(:Mount)
            @passedconfig = true
            unless options[:Mount].is_a?(Hash)
                raise Puppet::DevError, "Invalid mount options %s" %
                    options[:Mount].inspect
            end

            options[:Mount].each { |dir, name|
                if FileTest.exists?(dir)
                    mount(dir, name)
                end
            }
            mount(nil, MODULES)
        else
            @passedconfig = false
            readconfig(false) # don't check the file the first time.
        end
    end

    private :initialize

    # Mount a new directory with a name.
    def mount(path, name)
        if @mounts.include?(name)
            if @mounts[name] != path
                raise FileServerError, "%s is already mounted at %s" %
                    [@mounts[name].path, name]
            else
                # it's already mounted; no problem
                return
            end
        end

        # Let the mounts do their own error-checking.
        @mounts[name] = Mount.new(name, path)
        @mounts[name].info "Mounted %s" % path

        return @mounts[name]
    end

    def umount(name)
        @mounts.delete(name) if @mounts.include? name
    end

    private

    def authcheck(file, mount, client, clientip)
        # If we're local, don't bother passing in information.
        if local?
            client = nil
            clientip = nil
        end
        unless mount.allowed?(client, clientip)
            mount.warning "%s cannot access %s" %
                [client, file]
            raise Puppet::AuthorizationError, "Cannot access %s" % mount
        end
    end

    def convert(url, client, clientip)
        readconfig

        url = URI.unescape(url)

        mount, stub = splitpath(url, client)

        authcheck(url, mount, client, clientip)

        path = nil
        unless path = mount.subdir(stub, client)
            mount.notice "Could not find subdirectory %s" %
                "//%s/%s" % [mount, stub]
            return ""
        end

        return mount, path
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

    # Return the mount for the Puppet modules; allows file copying from
    # the modules.
    def modules_mount(module_name, client)
        # Find our environment, if we have one.
        unless hostname = (client || Facter.value("hostname"))
            raise ArgumentError, "Could not find hostname"
        end
        if node = Puppet::Node.find(hostname)
            env = node.environment
        else
            env = nil
        end

        # And use the environment to look up the module.
        mod = Puppet::Module::find(module_name, env)
        if mod
            return @mounts[MODULES].copy(mod.name, mod.files)
        else
            return nil
        end
    end

    # Read the configuration file.
    def readconfig(check = true)
        return if @noreadconfig

        if check and ! @config.changed?
            return
        end

        newmounts = {}
        begin
            File.open(@config.file) { |f|
                mount = nil
                count = 1
                f.each { |line|
                    case line
                    when /^\s*#/: next # skip comments
                    when /^\s*$/: next # skip blank lines
                    when /\[([-\w]+)\]/:
                        name = $1
                        if newmounts.include?(name)
                            raise FileServerError, "%s is already mounted at %s" %
                                [newmounts[name], name], count, @config.file
                        end
                        mount = Mount.new(name)
                        newmounts[name] = mount
                    when /^\s*(\w+)\s+(.+)$/:
                        var = $1
                        value = $2
                        case var
                        when "path":
                            if mount.name == MODULES
                                Puppet.warning "The '#{MODULES}' module can not have a path. Ignoring attempt to set it"
                            else
                                begin
                                    mount.path = value
                                rescue FileServerError => detail
                                    Puppet.err "Removing mount %s: %s" %
                                        [mount.name, detail]
                                    newmounts.delete(mount.name)
                                end
                            end
                        when "allow":
                            value.split(/\s*,\s*/).each { |val|
                                begin
                                    mount.info "allowing %s access" % val
                                    mount.allow(val)
                                rescue AuthStoreError => detail
                                    raise FileServerError.new(detail.to_s,
                                        count, @config.file)
                                end
                            }
                        when "deny":
                            value.split(/\s*,\s*/).each { |val|
                                begin
                                    mount.info "denying %s access" % val
                                    mount.deny(val)
                                rescue AuthStoreError => detail
                                    raise FileServerError.new(detail.to_s,
                                        count, @config.file)
                                end
                            }
                        else
                            raise FileServerError.new("Invalid argument '%s'" % var,
                                count, @config.file)
                        end
                    else
                        raise FileServerError.new("Invalid line '%s'" % line.chomp,
                            count, @config.file)
                    end
                    count += 1
                }
            }
        rescue Errno::EACCES => detail
            Puppet.err "FileServer error: Cannot read %s; cannot serve" % @config
            #raise Puppet::Error, "Cannot read %s" % @config
        rescue Errno::ENOENT => detail
            Puppet.err "FileServer error: '%s' does not exist; cannot serve" %
                @config
            #raise Puppet::Error, "%s does not exit" % @config
        #rescue FileServerError => detail
        #    Puppet.err "FileServer error: %s" % detail
        end

        unless newmounts[MODULES]
            mount = Mount.new(MODULES)
            mount.allow("*")
            newmounts[MODULES] = mount
        end

        # Verify each of the mounts are valid.
        # We let the check raise an error, so that it can raise an error
        # pointing to the specific problem.
        newmounts.each { |name, mount|
            unless mount.valid?
                raise FileServerError, "No path specified for mount %s" %
                    name
            end
        }
        @mounts = newmounts
    end

    # Split the path into the separate mount point and path.
    def splitpath(dir, client)
        # the dir is based on one of the mounts
        # so first retrieve the mount path
        mount = nil
        path = nil
        if dir =~ %r{/([-\w]+)/?}
            # Strip off the mount name.
            mount_name, path = dir.sub(%r{^/}, '').split(File::Separator, 2)

            unless mount = modules_mount(mount_name, client)
                unless mount = @mounts[mount_name]
                    raise FileServerError, "Fileserver module '%s' not mounted" % mount_name
                end
            end
        else
            raise FileServerError, "Fileserver error: Invalid path '%s'" % dir
        end

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
