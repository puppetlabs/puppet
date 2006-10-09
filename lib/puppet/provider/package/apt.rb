Puppet::Type.type(:package).provide :apt, :parent => :dpkg do
    # Provide sorting functionality
    include Puppet::Util::Package

    desc "Package management via ``apt-get``."

    commands :aptget => "/usr/bin/apt-get"
    commands :aptcache => "/usr/bin/apt-cache"
    commands :preseed => "/usr/bin/debconf-set-selections"

    defaultfor :operatingsystem => :debian

    ENV['DEBIAN_FRONTEND'] = "noninteractive"

    # A derivative of DPKG; this is how most people actually manage
    # Debian boxes, and the only thing that differs is that it can
    # install packages from remote sites.

    def aptcmd(arg)
        aptget(arg)
    end

    def checkforcdrom
        unless defined? @@checkedforcdrom
            if FileTest.exists? "/etc/apt/sources.list"
                if File.read("/etc/apt/sources.list") =~ /^[^#]*cdrom:/
                    @@checkedforcdrom = true
                else
                    @@checkedforcdrom = false
                end
            else
                # This is basically a pathalogical case, but we'll just
                # ignore it
                @@checkedforcdrom = false
            end
        end

        if @@checkedforcdrom and @model[:allowcdrom] != :true
            raise Puppet::Error,
                "/etc/apt/sources.list contains a cdrom source; not installing.  Use 'allowcdrom' to override this failure."
        end
    end

    attr_accessor :keepconfig

    # Install a package using 'apt-get'.  This function needs to support
    # installing a specific version.
    def install
        if @model[:responsefile]
            self.preseed
        end
        should = @model.should(:ensure)

        checkforcdrom()

        str = @model[:name]
        case should
        when true, false, Symbol
            # pass
        else
            # Add the package version
            str += "=%s" % should
        end

        keep = ""
        if defined? @keepconfig
            case @keepconfig
            when true
                keep = "-o 'DPkg::Options::=--force-confold'"
            else
                keep = "-o 'DPkg::Options::=--force-confnew'"
            end
        end
        
        aptcmd("-q -y %s install %s" % [keep, str])
    end

    # What's the latest package version available?
    def latest
        output = aptcache("showpkg %s" % @model[:name] )

        if output =~ /Versions:\s*\n((\n|.)+)^$/
            versions = $1
            version = versions.split(/\n/).collect { |version|
                if version =~ /^([^\(]+)\(/
                    $1
                else
                    self.warning "Could not match version '%s'" % version
                    nil
                end
            }.reject { |vers| vers.nil? }.sort { |a,b|
                versioncmp(a,b)
            }

            unless version
                self.debug "No latest version"
                if Puppet[:debug]
                    print output
                end
            end

            return version
        else
            self.err "Could not match string"
        end
    end

	#
	# preseeds answers to dpkg-set-selection from the "responsefile"
	#
    def preseed
        if response = @model[:responsefile] && FileTest.exists?(response)
            self.info("Preseeding %s to debconf-set-selections" % response)

            preseed response
        else 
            self.info "No responsefile specified or non existant, not preseeding anything"
        end
    end

    def update
        self.install
    end

    def uninstall
        aptcmd("-y -q remove %s" % @model[:name])
    end

    def versionable?
        true
    end
end

# $Id$
