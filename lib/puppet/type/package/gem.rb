module Puppet
    Puppet.type(:package).newpkgtype(:gem) do
        if gem = %x{which gem 2>/dev/null}.chomp and gem != ""
            @@gem = gem
        else
            @@gem = nil
        end
        def self.extended(mod)
            unless @@pkgget
                raise Puppet::Error,
                    "The gem command is missing; gems unavailable"
            end
        end

        def gemlist(hash)
            command = "#{@@gem} list "

            if hash[:local]
                command += "--local "
            else
                command += "--remote "
            end

            if hash[:justme]
                command += self[:name]
            end
            begin
                list = execute(command).split("\n\n").collect do |set|
                    if gemhash = gemsplit(set)
                        gemhash[:type] = :gem
                        gemhash[:ensure] = gemhash[:version][0]
                        gemhash
                    else
                        nil
                    end
                end.reject { |p| p.nil? }
            rescue ExecutionFailure => detail
                raise Puppet::Error, "Could not list gems: %s" % detail
            end

            if hash[:justme]
                return list.shift
            else
                return list
            end
        end

        module_function :gemlist

        def gemsplit(desc)
            case desc
            when /^\*\*\*/: return nil
            when /^(\S+)\s+\((.+)\)\n/
                name = $1
                version = $2.split(/,\s*/)
                return {
                    :name => name,
                    :version => version
                }
            else
                Puppet.warning "Could not match %s" % desc
                nil
            end
        end

        module_function :gemsplit

        def install(useversion = true)
            command = "#{@@gem} install "
            if self[:version] and useversion
                command += "-v %s " % self[:version]
            end
            if source = self[:source]
                command += source
            else
                command += self[:name]
            end
            begin
                execute(command)
            rescue ExecutionFailure => detail
                raise Puppet::Error, "Could not install %s: %s" %
                    [self[:name], detail]
            end
        end

        def latest
            # This always gets the latest version available.
            hash = gemlist(:justme => true)

            return hash[:version][0]
        end

        def list(justme = false)
            gemlist(:local => true).each do |hash|
                Puppet::Type.type(:package).installedpkg(hash)
            end
        end

        def query
            gemlist(:justme => true, :local => true)
        end

        def uninstall
            begin
                # Remove everything, including the binaries.
                execute("#{@@gem} uninstall -x -a #{self[:name]}")
            rescue ExecutionFailure => detail
                raise Puppet::Error, "Could not uninstall %s: %s" %
                    [self[:name], detail]
            end
        end

        def update
            self.install(false)
        end
    end
end

# $Id$
