# Description of yum repositories

require 'puppet/statechange'
require 'puppet/inifile'
require 'puppet/type/parsedtype'

module Puppet

    # A state for one entry in a .ini-style file
    class IniState < Puppet::State

        def insync?
            # A should state of :absent is the same as nil
            if is.nil? && (should.nil? || should == :absent)
                return true
            end
            return super
        end

        def sync
            if insync?
                result = nil
            else
                result = set
                if should == :absent
                    parent.section[inikey] = nil
                else
                    parent.section[inikey] = should
                end
            end
            return result
        end

        def retrieve
            @is = parent.section[inikey]
        end
        
        def inikey
            name.to_s
        end

        # Set the key associated with this state to KEY, instead
        # of using the state's NAME
        def self.inikey(key)
            # Override the inikey instance method
            # Is there a way to do this without resorting to strings ?
            # Using a block fails because the block can't access
            # the variable 'key' in the outer scope
            self.class_eval("def inikey ; \"#{key.to_s}\" ; end")
        end

    end

    # Doc string for states that can be made 'absent'
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
            # to change yumconf in any other context
            attr_accessor :yumconf
        end

        self.filetype = Puppet::FileType.filetype(:flat)

        @inifile = nil
        
        @yumconf = "/etc/yum.conf"

        # Where to put files for brand new sections
        @defaultrepodir = nil

        # Return the Puppet::IniConfig::File for the whole yum config
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
            result = Puppet::IniConfig::File.new()
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

        # Return the Puppet::IniConfig::Section with name NAME
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
        end

        def self.clear
            @inifile = nil
            @yumconf = "/etc/yum.conf"
            @defaultrepodir = nil
            super
        end

        # Return the Puppet::IniConfig::Section for this yumrepo element
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
            # not depend on a state and triggers storing, or insert another
            # change at the end of changes to trigger storing Both
            # solutions require that the StateChange interface be
            # abstracted so that it can work with a change that is not
            # directly backed by a State
            unless changes.empty?
                class << changes[-1]
                    def go
                        result = super
                        self.state.parent.store
                        return result
                    end
                end
            end
            return changes
        end

        # Store modifications to this yumrepo element back to disk
        def store
            self.class.store
        end

        newparam(:name) do
            desc "The name of the repository."
            isnamevar
        end

        newstate(:descr, :parent => Puppet::IniState) do
            desc "A human readable description of the repository. 
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
            inikey "name"
        end
        
        newstate(:mirrorlist, :parent => Puppet::IniState) do
            desc "The URL that holds the list of mirrors for this repository.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newstate(:baseurl, :parent => Puppet::IniState) do
            desc "The URL for this repository.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end
        
        newstate(:enabled, :parent => Puppet::IniState) do
            desc "Whether this repository is enabled or disabled. Possible 
                  values are '0', and '1'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newstate(:gpgcheck, :parent => Puppet::IniState) do
            desc "Whether to check the GPG signature on packages installed
                  from this repository. Possible values are '0', and '1'.
                  \n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newstate(:gpgkey, :parent => Puppet::IniState) do
            desc "The URL for the GPG key with which packages from this
                  repository are signed.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newstate(:include, :parent => Puppet::IniState) do
            desc "A URL from which to include the config.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newstate(:exclude, :parent => Puppet::IniState) do
            desc "List of shell globs. Matching packages will never be
                  considered in updates or installs for this repo.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
        end

        newstate(:includepkgs, :parent => Puppet::IniState) do
            desc "List of shell globs. If this is set, only packages
                  matching one of the globs will be considered for
                  update or install.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(/.*/) { }
        end

        newstate(:enablegroups, :parent => Puppet::IniState) do
            desc "Determines whether yum will allow the use of
              package groups for this  repository. Possible 
              values are '0', and '1'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newstate(:failovermethod, :parent => Puppet::IniState) do
            desc "Either 'roundrobin' or 'priority'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r(roundrobin|priority)) { }
        end

        newstate(:keepalive, :parent => Puppet::IniState) do
            desc "Either '1' or '0'. This tells yum whether or not HTTP/1.1 
              keepalive  should  be  used with this repository.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newstate(:timeout, :parent => Puppet::IniState) do
            desc "Number of seconds to wait for a connection before timing 
                  out.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{[0-9]+}) { }
        end

        newstate(:metadata_expire, :parent => Puppet::IniState) do
            desc "Number of seconds after which the metadata will expire.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{[0-9]+}) { }
        end

        
        
    end
end
