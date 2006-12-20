require 'etc'
require 'facter'
require 'puppet/type/state'

module Puppet
    newtype(:user) do
        newstate(:ensure) do
            newvalue(:present, :event => :user_created) do
                # Verify that they have provided everything necessary, if we
                # are trying to manage the user
#                if @parent.managed?
#                    @parent.class.states.each { |state|
#                        next if stateobj = @parent.state(state.name)
#                        next if state.name == :ensure
#
#                        unless state.autogen? or state.isoptional?
#                            if state.method_defined?(:autogen)
#                                @parent[state.name] = :auto
#                            else
#                                @parent.fail "Users require a value for %s" %
#                                    state.name
#                            end
#                        end
#                    }
#
#                    #if @states.empty?
#                    #    @parent[:comment] = @parent[:name]
#                    #end
#                end
                provider.create
            end

            newvalue(:absent, :event => :user_removed) do
                provider.delete
            end

            desc "The basic state that the object should be in."

            # If they're talking about the thing at all, they generally want to
            # say it should exist.
            #defaultto :present
            defaultto do
                if @parent.managed?
                    :present
                else
                    nil
                end
            end

            def change_to_s
                begin
                    if @is == :absent
                        return "created"
                    elsif self.should == :absent
                        return "removed"
                    else
                        return "%s changed '%s' to '%s'" %
                            [self.name, self.is_to_s, self.should_to_s]
                    end
                rescue Puppet::Error, Puppet::DevError
                    raise
                rescue => detail
                    raise Puppet::DevError,
                        "Could not convert change %s to string: %s" %
                        [self.name, detail]
                end
            end

            def retrieve
                if provider.exists?
                    @is = :present
                else
                    @is = :absent
                end
            end

            # The default 'sync' method only selects among a list of registered
            # values.
            def sync
                if self.insync?
                    self.info "already in sync"
                    return nil
                #else
                    #self.info "%s vs %s" % [self.is.inspect, self.should.inspect]
                end
                unless self.class.values
                    self.devfail "No values defined for %s" %
                        self.class.name
                end

                # Set ourselves to whatever our should value is.
                self.set(self.should)
            end

        end

        newstate(:uid) do
            desc "The user ID.  Must be specified numerically.  For new users
                being created, if no user ID is specified then one will be
                chosen automatically, which will likely result in the same user
                having different IDs on different systems, which is not
                recommended."

            munge do |value|
                case value
                when String
                    if value =~ /^[-0-9]+$/
                        value = Integer(value)
                    end
                when Symbol
                    unless value == :absent or value == :auto
                        self.devfail "Invalid UID %s" % value
                    end

                    if value == :auto
                        value = autogen()
                    end
                end

                return value
            end
        end

        newstate(:gid) do
            desc "The user's primary group.  Can be specified numerically or
                by name."
            
            def found?
                defined? @found and @found
            end

            munge do |gid|
                method = :getgrgid
                case gid
                when String
                    if gid =~ /^[-0-9]+$/
                        gid = Integer(gid)
                    else
                        method = :getgrnam
                    end
                when Symbol
                    unless gid == :auto or gid == :absent
                        self.devfail "Invalid GID %s" % gid
                    end
                    # these are treated specially by sync()
                    return gid
                end

                if group = Puppet::Util.gid(gid)
                    @found = true
                    return group
                else
                    @found = false
                    return gid
                end
            end

            # *shudder*  Make sure that we've looked up the group and gotten
            # an ID for it.  Yuck-o.
            def should
                unless defined? @should
                    return super
                end
                unless found?
                    @should = @should.each { |val|
                        next unless val
                        Puppet::Util.gid(val)
                    }
                end
                super
            end
        end

        newstate(:comment) do
            desc "A description of the user.  Generally is a user's full name."
            
            defaultto do
                "%s User" % @parent.title.capitalize
            end
        end

        newstate(:home) do
            desc "The home directory of the user.  The directory must be created
                separately and is not currently checked for existence."
            
            defaultto do
                if Facter.value(:operatingsystem) == "Darwin"
                    "/var/empty"
                end
            end
        end

        newstate(:shell) do
            desc "The user's login shell.  The shell must exist and be
                executable."
            
            defaultto do
                if Facter.value(:operatingsystem) == "Darwin"
                    "/usr/bin/false"
                end
            end
        end

        newstate(:groups) do
            desc "The groups of which the user is a member.  The primary
                group should not be listed.  Multiple groups should be
                specified as an array."

            def should_to_s
                self.should
            end

            def is_to_s
                @is.join(",")
            end

            # We need to override this because the groups need to
            # be joined with commas
            def should
                unless defined? @is
                    retrieve
                end

                @should ||= []

                if @parent[:membership] == :inclusive
                    return @should.sort.join(",")
                else
                    members = @should
                    if @is.is_a?(Array)
                        members += @is
                    end
                    return members.uniq.sort.join(",")
                end
            end

            def retrieve
                if tmp = provider.groups
                    @is = tmp.split(",")
                else
                    @is = :absent
                end
            end

            def insync?
                unless defined? @should and @should
                    return false
                end
                unless defined? @is and @is
                    return false
                end
                tmp = @is
                if @is.is_a? Array
                    tmp = @is.sort.join(",")
                end

                return tmp == self.should
            end

            validate do |value|
                if value =~ /^\d+$/
                    raise ArgumentError, "Group names must be provided, not numbers"
                end
            end
        end

        # these three states are all implemented differently on each platform,
        # so i'm disabling them for now

        # FIXME Puppet::State::UserLocked is currently non-functional
        #newstate(:locked) do
        #    desc "The expected return code.  An error will be returned if the
        #        executed command returns something else."
        #end

        # FIXME Puppet::State::UserExpire is currently non-functional
        #newstate(:expire) do
        #    desc "The expected return code.  An error will be returned if the
        #        executed command returns something else."
        #    @objectaddflag = "-e"
        #end

        # FIXME Puppet::State::UserInactive is currently non-functional
        #newstate(:inactive) do
        #    desc "The expected return code.  An error will be returned if the
        #        executed command returns something else."
        #    @objectaddflag = "-f"
        #end

        newparam(:name) do
            desc "User name.  While limitations are determined for
                each operating system, it is generally a good idea to keep to
                the degenerate 8 characters, beginning with a letter."
            isnamevar
        end

        newparam(:membership) do
            desc "Whether specified groups should be treated as the only groups
                of which the user is a member or whether they should merely
                be treated as the minimum membership list."
                
            newvalues(:inclusive, :minimum)

            defaultto :minimum
        end

        newparam(:allowdupe) do
            desc "Whether to allow duplicate UIDs."
                
            newvalues(:true, :false)

            defaultto false
        end

        @doc = "Manage users.  Currently can create and modify users, but
            cannot delete them.  Theoretically all of the parameters are
            optional, but if no parameters are specified the comment will
            be set to the user name in order to make the internals work out
            correctly.
            
            This element type uses the prescribed native tools for creating
            groups and generally uses POSIX APIs for retrieving information
            about them.  It does not directly modify /etc/passwd or anything.
            
            For most platforms, the tools used are ``useradd`` and its ilk;
            for Mac OS X, NetInfo is used.  This is currently unconfigurable,
            but if you desperately need it to be so, please contact us."

        # Autorequire the group, if it's around
        autorequire(:group) do
            #return nil unless @states.include?(:gid)
            #return nil unless groups = @states[:gid].shouldorig
            autos = []

            if @states.include?(:gid) and groups = @states[:gid].shouldorig
                groups = groups.collect { |group|
                    if group =~ /^\d+$/
                        Integer(group)
                    else
                        group
                    end
                }
                groups.each { |group|
                    case group
                    when Integer:
                        if obj = Puppet.type(:group).find { |gobj|
                            gobj.should(:gid) == group
                        }
                            autos << obj
                            
                        end
                    else
                        autos << group
                    end
                }
            end

            if @states.include?(:groups) and groups = @states[:groups].should.split(",")
                autos += groups
            end

            autos
        end

        def self.list_by_name
            users = []
            defaultprovider.listbyname do |user|
                users << user
            end
            return users
        end

        def self.list
            defaultprovider.list

            self.collect do |user|
                user
            end
        end

        def retrieve
            absent = false
            states().each { |state|
                if absent
                    state.is = :absent
                else
                    state.retrieve
                end

                if state.name == :ensure and state.is == :absent
                    absent = true
                    next
                end
            }
            #if provider.exists?
            #    super
            #else
            #    # the user does not exist
            #    @states.each { |name, state|
            #        state.is = :absent
            #    }
            #    return
            #end
        end
    end
end

# $Id$
