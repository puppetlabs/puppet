# Packaging using Peter Bonivart's pkgutil program.
Puppet::Type.type(:package).provide :pkgutil, :parent => :sun, :source => :sun do
    desc "Package management using Peter Bonivartg's ``pkgutil`` command on Solaris."
    pkguti = "pkgutil"
    if FileTest.executable?("/opt/csw/bin/pkgutil")
        pkguti = "/opt/csw/bin/pkgutil"
    end

    confine :operatingsystem => :solaris

    commands :pkguti => pkguti

    # This is so stupid, but then, so is blastwave.
    ENV["PAGER"] = "/usr/bin/cat"

    def self.extended(mod)
        unless command(:pkguti) != "pkgutil"
            raise Puppet::Error,
                "The pkgutil command is missing; pkgutil packaging unavailable"
        end

        unless FileTest.exists?("/var/pkg-get/admin")
            Puppet.notice "It is highly recommended you create '/var/pkg-get/admin'."
            Puppet.notice "See /var/pkg-get/admin-fullauto"
        end
    end

    def self.instances(hash = {})
        blastlist(hash).collect do |bhash|
            bhash.delete(:avail)
            new(bhash)
        end
    end

    # Turn our blastwave listing into a bunch of hashes.
    def self.blastlist(hash)
        command = ["-c"]

        if hash[:justme]
            command << hash[:justme]
        end

        output = pkguti command

        list = output.split("\n").collect do |line|
            next if line =~ /^#/
            next if line =~ /^WARNING/
            next if line =~ /localrev\s+remoterev/
            next if line =~ /installed\s+catalog/

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

            # Use the name method, so it works with subclasses.
            hash[:provider] = self.name

            return hash
        else
            Puppet.warning "Cannot match %s" % line
            return nil
        end
    end

    def install
        pkguti "-y", "-i", @resource[:name]
    end

    # Retrieve the version from the current package file.
    def latest
        hash = self.class.blastlist(:justme => @resource[:name])
        hash[:avail]
    end

    def query
        if hash = self.class.blastlist(:justme => @resource[:name])
            hash
        else
            {:ensure => :absent}
        end
    end

    # Remove the old package, and install the new one
    def update
        pkguti "-y", "-i", @resource[:name]
    end

    def uninstall
        pkguti "-y", "-r", @resource[:name]
    end
end
