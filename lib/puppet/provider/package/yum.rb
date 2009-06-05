Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
    desc "Support via ``yum``."

    has_feature :versionable

    commands :yum => "yum", :rpm => "rpm", :python => "python"

    YUMHELPER = File::join(File::dirname(__FILE__), "yumhelper.py")

    attr_accessor :latest_info

    if command('rpm')
        confine :true => begin
                rpm('--version')
           rescue Puppet::ExecutionFailure
               false
           else
               true
           end
    end

    defaultfor :operatingsystem => [:fedora, :centos, :redhat]

    def self.prefetch(packages)
        if Process.euid != 0
            raise Puppet::Error, "The yum provider can only be used as root"
        end
        super
        return unless packages.detect { |name, package| package.should(:ensure) == :latest }

         # collect our 'latest' info
         updates = {}
         python(YUMHELPER).each_line do |l|
             l.chomp!
             next if l.empty?
             if l[0,4] == "_pkg"
                 hash = nevra_to_hash(l[5..-1])
                 [hash[:name], "#{hash[:name]}.#{hash[:arch]}"].each  do |n|
                     updates[n] ||= []
                     updates[n] << hash
                 end
             end
         end

         # Add our 'latest' info to the providers.
         packages.each do |name, package|
             if info = updates[package[:name]]
                 package.provider.latest_info = info[0]
             end
         end
    end

    def install
        should = @resource.should(:ensure)
        self.debug "Ensuring => #{should}"
        wanted = @resource[:name]

        # XXX: We don't actually deal with epochs here.
        case should
        when true, false, Symbol
            # pass
            should = nil
        else
            # Add the package version
            wanted += "-%s" % should
        end

        output = yum "-d", "0", "-e", "0", "-y", :install, wanted

        is = self.query
        unless is
            raise Puppet::Error, "Could not find package %s" % self.name
        end

        # FIXME: Should we raise an exception even if should == :latest
        # and yum updated us to a version other than @param_hash[:ensure] ?
        if should && should != is[:ensure]
            raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead"
        end
    end

    # What's the latest package version available?
    def latest
        upd = latest_info
        unless upd.nil?
            # FIXME: there could be more than one update for a package
            # because of multiarch
            return "#{upd[:version]}-#{upd[:release]}"
        else
            # Yum didn't find updates, pretend the current
            # version is the latest
            if properties[:ensure] == :absent
                raise Puppet::DevError, "Tried to get latest on a missing package"
            end
            return properties[:ensure]
        end
    end

    def update
        # Install in yum can be used for update, too
        self.install
    end

    def purge
        yum "-y", :erase, @resource[:name]
    end
 end

