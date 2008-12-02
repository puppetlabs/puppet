# Manage NetInfo POSIX objects.
#
# This provider has been deprecated. You should be using the directoryservice
# nameservice provider instead.

require 'puppet/provider/nameservice/netinfo'

Puppet::Type.type(:user).provide :netinfo, :parent => Puppet::Provider::NameService::NetInfo do
    desc "User management in NetInfo.  Note that NetInfo is not smart enough to fill in default information
        for users, so this provider will use default settings for home (``/var/empty``), shell (``/usr/bin/false``),
        comment (the user name, capitalized), and password ('********').  These defaults are only used when the user is created.
        Note that password management probably does not really work -- OS X does not store the password in NetInfo itself,
        yet we cannot figure out how to store the encrypted password where OS X will look for it.  The main reason the password
        support is even there is so that a default password is created, which effectively locks people out, even if it does not
        enable us to set a password."
    commands :nireport => "nireport", :niutil => "niutil"

    options :comment, :key => "realname"
    options :password, :key => "passwd"


    autogen_defaults :home => "/var/empty", :shell => "/usr/bin/false", :password => '********'

    has_feature :manages_passwords

    verify :gid, "GID must be an integer" do |value|
        value.is_a? Integer
    end

    verify :uid, "UID must be an integer" do |value|
        value.is_a? Integer
    end

    def autogen_comment
        return @resource[:name].capitalize
    end

    # The list of all groups the user is a member of.  Different
    # user mgmt systems will need to override this method.
    def groups
        warnonce "The NetInfo provider is deprecated; use directoryservice instead"
        
        groups = []

        user = @resource[:name]
        # Retrieve them all from netinfo
        open("| #{command(:nireport)} / /groups name users") do |file|
            file.each do |line|
                name, members = line.split(/\s+/)
                next unless members
                next if members =~ /NoValue/
                members = members.split(",")

                if members.include? user
                    groups << name
                end
            end
        end

        groups.join(",")
    end

    # This is really lame.  We have to iterate over each
    # of the groups and add us to them.
    def groups=(groups)
        warnonce "The NetInfo provider is deprecated; use directoryservice instead"
        
        case groups
        when Fixnum:
            groups = [groups.to_s]
        when String
            groups = groups.split(/\s*,\s*/)
        else
            raise Puppet::DevError, "got invalid groups value %s of type %s" % [groups.class, groups]
        end
        # Get just the groups we need to modify
        diff = groups - (@is || [])

        data = {}
        open("| #{command(:nireport)} / /groups name users") do |file|
            file.each do |line|
                name, members = line.split(/\s+/)

                if members.nil? or members =~ /NoValue/
                    data[name] = []
                else
                    # Add each diff group's current members
                    data[name] = members.split(/,/)
                end
            end
        end

        user = @resource[:name]
        data.each do |name, members|
            if members.include? user and groups.include? name
                # I'm in the group and should be
                next
            elsif members.include? user
                # I'm in the group and shouldn't be
                setuserlist(name, members - [user])
            elsif groups.include? name
                # I'm not in the group and should be
                setuserlist(name, members + [user])
            else
                # I'm not in the group and shouldn't be
                next
            end
        end
    end
end

