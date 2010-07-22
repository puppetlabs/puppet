# Packaging using pkgutil from http://pkgutil.wikidot.com/
# vim:set sw=4 ts=4 sts=4:
Puppet::Type.type(:package).provide :pkgutil, :parent => :sun, :source => :sun do
    desc "Package management using ``pkgutil`` command on Solaris."
    pkgutil = "pkgutil"
    if FileTest.executable?("/opt/csw/bin/pkgutil")
        pkgutil = "/opt/csw/bin/pkgutil"
    end

    confine :operatingsystem => :solaris

    commands :pkgutil => pkgutil

    # This is so stupid, but then, so is Solaris.
    ENV["PAGER"] = "/usr/bin/cat"

    def self.extended(mod)
        unless command(:pkgutil) != "pkgutil"
            raise Puppet::Error,
                "The pkgutil command is missing; pkgutil packaging unavailable"
        end
    end

    # It's a class method. Returns a list of instances of this class.
    def self.instances(hash = {})
        blastlist(hash).collect do |bhash|
            bhash.delete(:avail)
            new(bhash)
        end
    end

    # Turn our pkgutil listing into a bunch of hashes.
    def self.blastlist(hash)
        command = ["-c"]

        if hash[:justme]
            command << ["--single"]
            command << hash[:justme]
        end

        output = pkgutil command

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

            # Use the name method, so it works with subclasses.
            hash[:provider] = self.name

            return hash
        else
            Puppet.warning "Cannot match %s" % line
            return nil
        end
    end

    def install
        pkgutil "-y", "--install", @resource[:name]
    end

    # What's the latest version of the package available?
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
        pkgutil "-y", "--upgrade", @resource[:name]
    end

    def uninstall
        pkgutil "-y", "--remove", @resource[:name]
    end
end
