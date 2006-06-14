require 'etc'
require 'facter'
require 'puppet/type/state'
require 'puppet/type/nameservice'

module Puppet
    newtype(:user, Puppet::Type::NSSType) do
        case Facter["operatingsystem"].value
        when "Darwin":
            @parentstate = Puppet::NameService::NetInfo::NetInfoState
            @parentmodule = Puppet::NameService::NetInfo
        when "FreeBSD":
            @parentstate = Puppet::NameService::PW::PWUser
            @parentmodule = Puppet::NameService::PW
        else
            @parentstate = Puppet::NameService::ObjectAdd::ObjectAddUser
            @parentmodule = Puppet::NameService::ObjectAdd
        end

        newstate(:ensure, @parentstate) do
            newvalue(:present) do
                # Verify that they have provided everything necessary, if we
                # are trying to manage the user
                if @parent.managed?
                    @parent.class.states.each { |state|
                        next if stateobj = @parent.state(state.name)
                        next if state.name == :ensure

                        unless state.autogen? or state.isoptional?
                            if state.method_defined?(:autogen)
                                @parent[state.name] = :auto
                            else
                                @parent.fail "Users require a value for %s" %
                                    state.name
                            end
                        end
                    }

                    #if @states.empty?
                    #    @parent[:comment] = @parent[:name]
                    #end
                end
                self.syncname(:present)
            end

            newvalue(:absent) do
                self.syncname(:absent)
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
                if @parent.exists?
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
                self.set
            end

        end

        newstate(:uid, @parentstate) do
            desc "The user ID.  Must be specified numerically.  For new users
                being created, if no user ID is specified then one will be
                chosen automatically, which will likely result in the same user
                having different IDs on different systems, which is not
                recommended."

            isautogen

            def autogen
                highest = 0
                Etc.passwd { |user|
                    if user.uid > highest
                        unless user.uid > 65000
                            highest = user.uid
                        end
                    end
                }

                return highest + 1
            end

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

        newstate(:gid, @parentstate) do
            desc "The user's primary group.  Can be specified numerically or
                by name."

            isautogen

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
                unless defined? @found and @found
                    @should = @should.each { |val|
                        next unless val
                        Puppet::Util.gid(val)
                    }
                end
                super
            end

        end

        newstate(:comment, @parentstate) do
            desc "A description of the user.  Generally is a user's full name."

            isoptional

            @posixmethod = :gecos
        end

        newstate(:home, @parentstate) do
            desc "The home directory of the user.  The directory must be created
                separately and is not currently checked for existence."

            isautogen
            @posixmethod = :dir
        end

        newstate(:shell, @parentstate) do
            desc "The user's login shell.  The shell must exist and be
                executable."
            isautogen
        end

        newstate(:groups, @parentstate) do
            desc "The groups of which the user is a member.  The primary
                group should not be listed.  Multiple groups should be
                specified as an array."

            isoptional

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
                    @should.sort.join(",")
                else
                    members = @should
                    if @is.is_a?(Array)
                        members += @is
                    end
                    members.uniq.sort.join(",")
                    #(@is + @should).uniq.sort.join(",")
                end
            end

            def retrieve
                @is = grouplist()
            end

            def insync?
                unless defined? @should and @should
                    return false
                end
                unless defined? @is and @is
                    return false
                end
                unless @is.class == @should.class
                    return false
                end
                return @is.sort == @should.sort
            end

            validate do |value|
                if value =~ /^\d+$/
                    raise ArgumentError, "Group names must be provided, not numbers"
                end
            end

            def sync
                if respond_to? :setgrouplist
                    # Pass them the group list, so that the :membership logic
                    # is all in this class, not in parent classes.
                    setgrouplist(self.should)
                    return :user_modified
                else
                    super
                end
            end
        end

        # these three states are all implemented differently on each platform,
        # so i'm disabling them for now

        # FIXME Puppet::State::UserLocked is currently non-functional
        #newstate(:locked, @parentstate) do
        #    desc "The expected return code.  An error will be returned if the
        #        executed command returns something else."
        #end

        # FIXME Puppet::State::UserExpire is currently non-functional
        #newstate(:expire, @parentstate) do
        #    desc "The expected return code.  An error will be returned if the
        #        executed command returns something else."
        #    @objectaddflag = "-e"
        #    isautogen
        #end

        # FIXME Puppet::State::UserInactive is currently non-functional
        #newstate(:inactive, @parentstate) do
        #    desc "The expected return code.  An error will be returned if the
        #        executed command returns something else."
        #    @objectaddflag = "-f"
        #    isautogen
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

        @netinfodir = "users"

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

            autos
        end

        autorequire(:file) do
            dir = self.should(:home) or self.is(:home)
            if dir =~ /^#{File::SEPARATOR}/
                dir
            else
                nil
            end
        end

        # List all found users
        def self.listbyname
            users = []
            Etc.setpwent
            while ent = Etc.getpwent
                users << ent.name
            end
            Etc.endpwent

            return users
        end

        def exists?
            self.class.parentmodule.exists?(self)
        end

        def getinfo(refresh = false)
            if @userinfo.nil? or refresh == true
                begin
                    @userinfo = Etc.getpwnam(self[:name])
                rescue ArgumentError => detail
                    @userinfo = nil
                end
            end

            @userinfo
        end

        def initialize(hash)
            @userinfo = nil
            super

            unless defined? @states
                raise "wtf?"
            end
        end

        def retrieve
            info = self.getinfo(true)

            if info.nil?
                # the user does not exist
                @states.each { |name, state|
                    state.is = :absent
                }
                return
            else
                super
            end
        end
    end
end

# $Id$
