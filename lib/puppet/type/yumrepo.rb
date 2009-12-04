# Description of yum repositories

require 'puppet/util/inifile'

module Puppet
    # A property for one entry in a .ini-style file
    class IniProperty < Puppet::Property
        def insync?(is)
            # A should property of :absent is the same as nil
            if is.nil? && (should.nil? || should == :absent)
                return true
            end
            return super(is)
        end

        def sync
            if insync?(retrieve)
                result = nil
            else
                result = set(self.should)
                if should == :absent
                    resource.section[inikey] = nil
                else
                    resource.section[inikey] = should
                end
            end
            return result
        end

        def retrieve
            return resource.section[inikey]
        end

        def inikey
            name.to_s
        end

        # Set the key associated with this property to KEY, instead
        # of using the property's NAME
        def self.inikey(key)
            # Override the inikey instance method
            # Is there a way to do this without resorting to strings ?
            # Using a block fails because the block can't access
            # the variable 'key' in the outer scope
            self.class_eval("def inikey ; \"#{key.to_s}\" ; end")
        end

    end

    # Doc string for properties that can be made 'absent'
    ABSENT_DOC="Set this to 'absent' to remove it from the file completely"

    newtype(:yumrepo) do
        @doc = "The client-side description of a yum repository. Repository
                configurations are found by parsing /etc/yum.conf and
                the files indicated by reposdir in that file (see yum.conf(5)
                for details)

                Most parameters are identical to the ones documented
                in yum.conf(5)

                Continuation lines that yum supports for example for the
                baseurl are not supported. No attempt is made to access
                files included with the **include** directive"

        class << self
            attr_accessor :filetype
            # The writer is only used for testing, there should be no need
            # to change yumconf or inifile in any other context
            attr_accessor :yumconf
            attr_writer :inifile
        end

        self.filetype = Puppet::Util::FileType.filetype(:flat)

        @inifile = nil

        @yumconf = "/etc/yum.conf"

        # Where to put files for brand new sections
        @defaultrepodir = nil

        def self.instances
            l = []
            check = validproperties
            clear
            inifile.each_section do |s|
                next if s.name == "main"
                obj = create(:name => s.name, :check => check)
                current_values = obj.retrieve
                obj.eachproperty do |property|
                    if current_values[property].nil?
                        obj.delete(property.name)
                    else
                        property.should = current_values[property]
                    end
                end
                obj.delete(:check)
                l << obj
            end
            l
        end

        # Return the Puppet::Util::IniConfig::File for the whole yum config
        def self.inifile
            if @inifile.nil?
                @inifile = read()
                main = @inifile['main']
                if main.nil?
                    raise Puppet::Error, "File #{yumconf} does not contain a main section"
                end
                reposdir = main['reposdir']
                reposdir ||= "/etc/yum.repos.d, /etc/yum/repos.d"
                reposdir.gsub!(/[\n,]/, " ")
                reposdir.split.each do |dir|
                    Dir::glob("#{dir}/*.repo").each do |file|
                        if File.file?(file)
                            @inifile.read(file)
                        end
                    end
                end
                reposdir.split.each do |dir|
                    if File::directory?(dir) && File::writable?(dir)
                        @defaultrepodir = dir
                        break
                    end
                end
            end
            return @inifile
        end

        # Parse the yum config files. Only exposed for the tests
        # Non-test code should use self.inifile to get at the
        # underlying file
        def self.read
            result = Puppet::Util::IniConfig::File.new()
            result.read(yumconf)
            main = result['main']
            if main.nil?
                raise Puppet::Error, "File #{yumconf} does not contain a main section"
            end
            reposdir = main['reposdir']
            reposdir ||= "/etc/yum.repos.d, /etc/yum/repos.d"
            reposdir.gsub!(/[\n,]/, " ")
            reposdir.split.each do |dir|
                Dir::glob("#{dir}/*.repo").each do |file|
                    if File.file?(file)
                        result.read(file)
                    end
                end
            end
            if @defaultrepodir.nil?
                reposdir.split.each do |dir|
                    if File::directory?(dir) && File::writable?(dir)
                        @defaultrepodir = dir
                        break
                    end
                end
            end
            return result
        end

        # Return the Puppet::Util::IniConfig::Section with name NAME
        # from the yum config
        def self.section(name)
            result = inifile[name]
            if result.nil?
                # Brand new section
                path = yumconf
                unless @defaultrepodir.nil?
                    path = File::join(@defaultrepodir, "#{name}.repo")
                end
                Puppet::info "create new repo #{name} in file #{path}"
                result = inifile.add_section(name, path)
            end
            return result
        end

        # Store all modifications back to disk
        def self.store
            inifile.store
            unless Puppet[:noop]
                target_mode = 0644 # FIXME: should be configurable
                inifile.each_file do |file|
                    current_mode = File.stat(file).mode & 0777
                    unless current_mode == target_mode
                        Puppet::info "changing mode of #{file} from %03o to %03o" % [current_mode, target_mode]
                        File.chmod(target_mode, file)
                    end
                end
            end
        end

        # This is only used during testing.
        def self.clear
            @inifile = nil
            @yumconf = "/etc/yum.conf"
            @defaultrepodir = nil
        end

        # Return the Puppet::Util::IniConfig::Section for this yumrepo resource
        def section
            self.class.section(self[:name])
        end

        def evaluate
            changes = super
            # FIXME: Dirty, dirty hack
            # We amend the go method of the last change to trigger
            # writing the whole file
            # A cleaner solution would be to either use the composite
            # pattern and encapsulate all changes into a change that does
            # not depend on a property and triggers storing, or insert another
            # change at the end of changes to trigger storing Both
            # solutions require that the PropertyChange interface be
            # abstracted so that it can work with a change that is not
            # directly backed by a Property
            unless changes.empty?
                class << changes[-1]
                    def go
                        result = super
                        self.property.resource.store
                        return result
                    end
                end
            end
            return changes
        end

        # Store modifications to this yumrepo resource back to disk
        def store
            self.class.store
        end

        newparam(:name) do
            desc "The name of the repository.  This corresponds to the
                  repositoryid parameter in yum.conf(5)."
            isnamevar
        end

        newproperty(:descr, :parent => Puppet::IniProperty) do
            desc "A human readable description of the repository.
                  This corresponds to the name parameter in yum.conf(5).
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
            inikey "name"
        end

        newproperty(:mirrorlist, :parent => Puppet::IniProperty) do
            desc "The URL that holds the list of mirrors for this repository.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newproperty(:baseurl, :parent => Puppet::IniProperty) do
            desc "The URL for this repository.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newproperty(:enabled, :parent => Puppet::IniProperty) do
            desc "Whether this repository is enabled or disabled. Possible
                  values are '0', and '1'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newproperty(:gpgcheck, :parent => Puppet::IniProperty) do
            desc "Whether to check the GPG signature on packages installed
                  from this repository. Possible values are '0', and '1'.
                  \n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newproperty(:gpgkey, :parent => Puppet::IniProperty) do
            desc "The URL for the GPG key with which packages from this
                  repository are signed.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newproperty(:include, :parent => Puppet::IniProperty) do
            desc "A URL from which to include the config.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newproperty(:exclude, :parent => Puppet::IniProperty) do
            desc "List of shell globs. Matching packages will never be
                  considered in updates or installs for this repo.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
        end

        newproperty(:includepkgs, :parent => Puppet::IniProperty) do
            desc "List of shell globs. If this is set, only packages
                  matching one of the globs will be considered for
                  update or install.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
        end

        newproperty(:enablegroups, :parent => Puppet::IniProperty) do
            desc "Determines whether yum will allow the use of
              package groups for this  repository. Possible
              values are '0', and '1'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newproperty(:failovermethod, :parent => Puppet::IniProperty) do
            desc "Either 'roundrobin' or 'priority'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r(roundrobin|priority)) { }
        end

        newproperty(:keepalive, :parent => Puppet::IniProperty) do
            desc "Either '1' or '0'. This tells yum whether or not HTTP/1.1
              keepalive  should  be  used with this repository.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newproperty(:timeout, :parent => Puppet::IniProperty) do
            desc "Number of seconds to wait for a connection before timing
                  out.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{[0-9]+}) { }
        end

        newproperty(:metadata_expire, :parent => Puppet::IniProperty) do
            desc "Number of seconds after which the metadata will expire.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{[0-9]+}) { }
        end

        newproperty(:protect, :parent => Puppet::IniProperty) do
            desc "Enable or disable protection for this repository. Requires
                  that the protectbase plugin is installed and enabled.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newproperty(:priority, :parent => Puppet::IniProperty) do
            desc "Priority of this repository from 1-99. Requires that
                  the priorities plugin is installed and enabled.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{[1-9][0-9]?}) { }
        end

        newproperty(:proxy, :parent => Puppet::IniProperty) do
            desc "URL to the proxy server for this repository.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newproperty(:proxy_username, :parent => Puppet::IniProperty) do
            desc "Username for this proxy.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
        end

        newproperty(:proxy_password, :parent => Puppet::IniProperty) do
            desc "Password for this proxy.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
        end
    end
end
