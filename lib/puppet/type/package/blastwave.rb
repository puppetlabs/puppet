module Puppet
    Puppet.type(:package).newpkgtype(:blastwave, :sun) do
        if pkgget = %x{which pkg-get 2>/dev/null}.chomp and pkgget != ""
            @@pkgget = pkgget
        else
            @@pkgget = nil
        end

        # This is so stupid
        ENV["PAGER"] = "/usr/bin/cat"

        def self.extended(mod)
            unless @@pkgget
                raise Puppet::Error,
                    "The pkg-get command is missing; blastwave packaging unavailable"
            end

            unless FileTest.exists?("/var/pkg-get/admin")
                Puppet.notice "It is highly recommended you create '/var/pkg-get/admin'."
                Puppet.notice "See /var/pkg-get/admin-fullauto"
            end
        end

        # Turn our blastwave listing into a bunch of hashes.
        def blastlist(hash)
            command = "#{@@pkgget} -c"

            if hash[:justme]
                command += " " + self[:name]
            end

            begin
                output = execute(command)
            rescue ExecutionError => detail
                raise Puppet::Error, "Could not get package listing: %s" %
                    detail
            end

            list = output.split("\n").collect do |line|
                next if line =~ /^#/
                next if line =~ /^WARNING/
                next if line =~ /localrev\s+remoterev/

                blastsplit(line)
            end.reject { |h| h.nil? }

            if hash[:justme]
                return list[0]
            else
                list.reject! { |h|
                    h[:ensure] == :absent
                }
                return list
            end

        end

        # Split the different lines into hashes.
        def blastsplit(line)
            if line =~ /\s*(\S+)\s+((\[Not installed\])|(\S+))\s+(\S+)/
                hash = {}
                hash[:name] = $1
                hash[:ensure] = if $2 == "[Not installed]"
                    :absent
                else
                    $2
                end
                hash[:avail] = $5

                if hash[:avail] == "SAME"
                    hash[:avail] = hash[:ensure]
                end
                hash[:type] = :blastwave

                return hash
            else
                Puppet.warning "Cannot match %s" % line
                return nil
            end
        end

        module_function :blastlist, :blastsplit

        def install
            begin
                execute("#{@@pkgget} -f install #{self[:name]}")
            rescue ExecutionFailure => detail
                raise Puppet::Error,
                    "Could not install %s: %s" %
                    [self[:name], detail]
            end
        end

        # Retrieve the version from the current package file.
        def latest
            hash = blastlist(:justme => true)
            hash[:avail]
        end

        def list(hash = {})
            blastlist(hash).each do |bhash|
                bhash.delete(:avail)
                Puppet::Type.type(:package).installedpkg(bhash)
            end
        end

        def query
            hash = blastlist(:justme => true)

            {:ensure => hash[:ensure]}
        end

        # Remove the old package, and install the new one
        def update
            begin
                execute("#{@@pkgget} -f upgrade #{self[:name]}")
            rescue ExecutionFailure => detail
                raise Puppet::Error,
                    "Could not upgrade %s: %s" %
                    [self[:name], detail]
            end
        end

        def uninstall
            begin
                execute("#{@@pkgget} -f remove #{self[:name]}")
            rescue ExecutionFailure => detail
                raise Puppet::Error,
                    "Could not remove %s: %s" %
                    [self[:name], detail]
            end
        end
    end
end

# $Id$
