require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    # The Puppet::CronType modules are responsible for the actual abstraction.
    # They must implement three module functions: +read+, +write+, and +remove+,
    # analogous to the three flags accepted by most implementations of +hosttab+.
    # All of these methods require the user name to be passed in.
    #
    # These modules operate on the strings that are ore become the host tabs --
    # they do not have any semantic understanding of what they are reading or
    # writing.
    module FileType

        # This module covers nearly everyone; SunOS is only known exception so far.
        class Flat
            attr_accessor :loaded, :path, :synced
            def initialize(path)
                @path = path
            end

            # Read the file.
            def read
                if File.exists?(@path)
                    @loaded = Time.now
                    File.read(@path)
                else
                    return nil
                end
            end

            # Remove the file.
            def remove
                if File.exists?(@path)
                    File.unlink(@path)
                end
            end

            # Overwrite the file.
            def self
                @synced = Time.now
                File.open(@path, "w") { |f| f.print text; f.flush }
            end
        end
    end

    newtype(:host) do
        class HostParam < Puppet::State
            # Normally this would retrieve the current value, but our state is not
            # actually capable of doing so.
            def retrieve
                unless defined? @is and ! @is.nil?
                    @is = :notfound
                end
            end

            # Determine whether the host entry should be destroyed, and figure
            # out which event to return.  Finally, call @parent.sync to write the
            # host tab.
            def sync(nostore = false)
                event = nil
                if @is == :notfound
                    @is = self.should
                    event = :host_created
                elsif self.should == :notfound
                    @parent.remove(true)
                    event = :host_deleted
                elsif self.insync?
                    return nil
                else
                    @is = self.should
                    event = :host_changed
                end

                unless nostore
                    @parent.store
                end
                
                return event
            end
        end

        newstate(:ip, HostParam) do
            desc "The host's IP address."
        end

        newstate(:alias, HostParam) do
            desc "Any aliases the host might have.  Values can be either an array
                or a comma-separated list."

            # We have to override the feeding mechanism; it might be nil or 
            # white-space separated
            def is=(value)
                # If it's just whitespace, ignore it
                if value =~ /^\s+$/
                    @is = nil
                else
                    # Else split based on whitespace and store as an array
                    @is = value.split(/\s+/)
                end
            end

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                @should
            end

            munge do |value|
                unless value.is_a?(Array)
                    value = [value]
                end
                # Split based on comma, then flatten the whole thing
                value.collect { |value|
                    value.split(/,\s*/)
                }.flatten
            end
        end

        newparam(:name) do
            desc "The host name."

            isnamevar
        end

        @doc = "Installs and manages host entries.  For most systems, these
            entries will just be in /etc/hosts, but some systems (notably OS X)
            will have different solutions."

        @instances = []

        @hostfile = "/etc/hosts"

        @hosttype = Puppet::FileType::Flat
#        case Facter["operatingsystem"].value
#        when "Solaris":
#            @hosttype = Puppet::FileType::SunOS
#        else
#            @hosttype = Puppet::CronType::Default
#        end

        class << self
            attr_accessor :hosttype, :hostfile, :fileobj
        end

        # Override the Puppet::Type#[]= method so that we can store the instances
        # in per-user arrays.  Then just call +super+.
        def self.[]=(name, object)
            self.instance(object)
            super
        end

        # In addition to removing the instances in @objects, Cron has to remove
        # per-user host tab information.
        def self.clear
            @instances = []
            @fileobj = nil
            super
        end

        # Override the default Puppet::Type method, because instances
        # also need to be deleted from the @instances hash
        def self.delete(child)
            if @instances.include?(child)
                @instances.delete(child)
            end
            super
        end

        def self.fields
            [:ip, :name, :alias]
        end

        # Return the header placed at the top of each generated file, warning
        # users that modifying this file manually is probably a bad idea.
        def self.header
%{# This file was autogenerated at #{Time.now} by puppet.  While it
# can still be managed manually, it is definitely not recommended.\n\n}
        end

        # Store a new instance of a host.  Called from Host#initialize.
        def self.instance(obj)
            unless @instances.include?(obj)
                @instances << obj
            end
        end

        # Parse a host file
        #
        # This method also stores existing comments, and it stores all host
        # jobs in order, mostly so that comments are retained in the order
        # they were written and in proximity to the same jobs.
        def self.parse(text)
            count = 0
            hash = {}
            text.chomp.split("\n").each { |line|
                case line
                when /^#/, /^\s*$/:
                    # add comments and blank lines to the list as they are
                    @instances << line 
                else
                    if match = /^(\S+)\s+(\S+)\s*(\S+)$/.match(line)
                        fields().zip(match.captures).each { |param, value|
                            hash[param] = value
                        }
                    else
                        raise Puppet::Error, "Could not match '%s'" % line
                    end

                    host = nil
                    # if the host already exists with that name...
                    if host = Puppet.type(:host)[hash[:name]]
                        # do nothing...
                    else
                        # create a new host, since no existing one seems to
                        # match
                        host = self.create(
                            :name => hash[:name]
                        )
                        hash.delete(:name)
                    end

                    hash.each { |param, value|
                        host.is = [param, value]
                    }
                    hash.clear
                    count += 1
                end
            }
        end

        # Retrieve the text for the hosts file. Returns nil in the unlikely event
        # that it doesn't exist.
        def self.retrieve
            @fileobj ||= @hosttype.new(@hostfile)
            text = @fileobj.read
            if text.nil? or text == ""
                # there is no host file
                return nil
            else
                self.parse(text)
            end
        end

        # Write out the hosts file.
        def self.store
            @fileobj ||= @hosttype.new(@hostfile)

            if @instances.empty?
                Puppet.notice "No host instances for %s" % user
            else
                @fileobj.write(self.to_file())
            end
        end

        # Collect all Host instances convert them into literal text.
        def self.to_file
            str = self.header()
            unless @instances.empty?
                str += @instances.collect { |obj|
                    if obj.is_a? self
                        obj.to_host
                    else
                        obj.to_s
                    end
                }.join("\n") + "\n"

                return str
            else
                Puppet.notice "No host instances for %s" % user
                return ""
            end
        end

        # Return the last time the hosts file was loaded.  Could
        # be used for reducing writes, but currently is not.
        def self.loaded?(user)
            @fileobj ||= @hosttype.new(@hostfile)
            @fileobj.loaded
        end

        # Override the default Puppet::Type method because we need to call
        # the +@hosttype+ retrieve method.
        def retrieve
            @fileobj ||= @hosttype.new(@hostfile)
            self.class.retrieve()
            self.eachstate { |st| st.retrieve }
        end

        # Write the entire host file out.
        def store
            self.class.store()
        end

        # Convert the current object into a host-style string.
        def to_host
            str = "%s\t%s" % [self.state(:ip).should, self[:name]]

            if state = self.state(:alias)
                str += "\t%s" % state.should.join("\t")
            end

            str
        end
    end
end

# $Id$
