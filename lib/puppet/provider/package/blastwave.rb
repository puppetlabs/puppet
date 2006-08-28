# Packaging using Blastwave's pkg-get program.
Puppet::Type.type(:package).provide :blastwave, :parent => :sun do
    desc "Package management using Blastwave.org's ``pkg-get`` command on Solaris."
    pkgget = "pkg-get"
    if FileTest.executable?("/opt/csw/bin/pkg-get")
        pkgget = "/opt/csw/bin/pkg-get"
    end

    commands :pkgget => pkgget

    # This is so stupid, but then, so is blastwave.
    ENV["PAGER"] = "/usr/bin/cat"

    def self.extended(mod)
        unless command(:pkgget) != "pkg-get"
            raise Puppet::Error,
                "The pkg-get command is missing; blastwave packaging unavailable"
        end

        unless FileTest.exists?("/var/pkg-get/admin")
            Puppet.notice "It is highly recommended you create '/var/pkg-get/admin'."
            Puppet.notice "See /var/pkg-get/admin-fullauto"
        end
    end

    def self.list(hash = {})
        blastlist(hash).each do |bhash|
            bhash.delete(:avail)
            Puppet::Type.type(:package).installedpkg(bhash)
        end
    end

    # Turn our blastwave listing into a bunch of hashes.
    def self.blastlist(hash)
        command = "#{command(:pkgget)} -c"

        if hash[:justme]
            command += " " + hash[:justme]
        end

        begin
            output = execute(command)
        rescue Puppet::ExecutionFailure => detail
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
    def self.blastsplit(line)
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
            hash[:provider] = :blastwave

            return hash
        else
            Puppet.warning "Cannot match %s" % line
            return nil
        end
    end

    def install
        begin
            execute("#{command(:pkgget)} -f install #{@model[:name]}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error,
                "Could not install %s: %s" %
                [@model[:name], detail]
        end
    end

    # Retrieve the version from the current package file.
    def latest
        hash = self.class.blastlist(:justme => @model[:name])
        hash[:avail]
    end

    def query
        hash = self.class.blastlist(:justme => @model[:name])

        {:ensure => hash[:ensure]}
    end

    # Remove the old package, and install the new one
    def update
        begin
            execute("#{command(:pkgget)} -f upgrade #{@model[:name]}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error,
                "Could not upgrade %s: %s" %
                [@model[:name], detail]
        end
    end

    def uninstall
        begin
            execute("#{command(:pkgget)} -f remove #{@model[:name]}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error,
                "Could not remove %s: %s" %
                [@model[:name], detail]
        end
    end
end

# $Id$
