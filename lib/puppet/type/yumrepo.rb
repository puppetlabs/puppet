# Description of yum repositories

require 'puppet/statechange'
require 'puppet/type/parsedtype'

module Puppet

    # A state for one entry in a .ini-style file
    class IniState < Puppet::State

        def insync?
            # A should state of :absent is the same as nil
            if self.is.nil? && (self.should.nil? || self.should == :absent)
                return true
            end
            return super
        end

        def inikey
            self.name
        end

        def format
            "#{self.inikey}=#{self.should}"
        end

        def emit
            self.should.nil? || self.should == :absent ? "" : "#{format}\n"
        end
    end

    # A state for the section header in a .ini-style file
    class IniSectionState < IniState
        def format
            "[#{self.should}]"
        end
    end

    # Doc string for states that can be made 'absent'
    ABSENT_DOC="Set this to 'absent' to remove it from the file completely"

    newtype(:yumrepo) do
        @doc = "The client-side description of a yum repository. Manages
                the yum repository configuration in the file '$name.repo',
                usually in the directory /etc/yum.repos.d, though the 
                directory can be set with the **repodir** parameter.

                Most parameters are identical to the ones documented 
                in yum.conf(5)

                Note that the proper working of this type requires that
                configurations for individual repos are kept in
                separate files in **repodir**, and that no attention
                is paid to the overall /etc/yum.conf"

        class << self
            attr_accessor :filetype
        end

        self.filetype = Puppet::FileType.filetype(:flat)

        def path
            File.join(self[:repodir], "#{self[:name]}.repo")
        end

        def retrieve
            Puppet.debug "Parsing yum config %s" % path
            text = self.class.filetype().new(path).read
            # Keep track of how entries were in the initial file
            # and preserve comments. @lines holds either original
            # lines (for comments) or a symbol for the entry that was there
            @lines = []
            text.each_line do |l|
                if l =~ /^\[(.+)\]$/
                    self.is = [:repoid, $1]
                    @lines << :repoid
                elsif l =~ /^(\s*\#|\s*$)/
                    # Preserve comments and empty lines
                    @lines << l
                elsif l =~ /^(.+)\=(.+)$/
                    key = $1.to_sym
                    key = :descr if $1 == "name"
                    self.is = [key, $2]
                    @lines << key
                end
            end
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

        def should(name)
            state(name).should
        end

        def store
            text = ""
            @lines.each do |l|
                if l.is_a?(String)
                    text << l
                else
                    text << state(l).emit
                end
            end
            self.each do |state|
                if state.is.nil? || state.is == :absent
                    # State was not in the parsed config file
                    text << state.emit
                end
            end
            Puppet.debug "Writing yum config %s" % path
            self.class.filetype().new(path).write(text)
        end

        newparam(:name) do
            desc "The name of the repository. This is used to find the config
                  file as $repodir/$name.repo"
            isnamevar
        end

        newparam(:repodir) do
            desc "The directory in which repo config files are to be found. 
                  Defaults to /etc/yum.repos.d"
            defaultto("/etc/yum.repos.d")
        end

        newstate(:repoid, Puppet::IniSectionState) do
            desc "The id that yum uses internally to keep track of 
                  the repository"
            newvalue(/.*/) { }
        end

        newstate(:descr, Puppet::IniState) do
            desc "A human readable description of the repository. Corresponds
                  to the 'name' parameter in the yum config file.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = nil }
            newvalue(/.*/) { }
            def inikey
                :name
            end
        end
        
        newstate(:mirrorlist, Puppet::IniState) do
            desc "The URL that holds the list of mirrors for this repository.
                  #{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

        newstate(:baseurl, Puppet::IniState) do
            desc "The URL for this repository.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end
        
        newstate(:enabled, Puppet::IniState) do
            desc "Whether this repository is enabled or disabled. Possible 
                  values are '0', and '1'.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newstate(:gpgcheck, Puppet::IniState) do
            desc "Whether to check the GPG signature on packages installed
                  from this repository. Possible values are '0', and '1'.
                  \n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            newvalue(%r{(0|1)}) { }
        end

        newstate(:gpgkey, Puppet::IniState) do
            desc "The URL for the GPG key with which packages from this
                  repository are signed.\n#{ABSENT_DOC}"
            newvalue(:absent) { self.should = :absent }
            # Should really check that it's a valid URL
            newvalue(/.*/) { }
        end

    end
end
