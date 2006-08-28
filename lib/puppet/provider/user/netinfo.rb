# Manage NetInfo POSIX objects.  Probably only used on OS X, but I suppose
# it could be used elsewhere.
require 'puppet/provider/nameservice/netinfo'

Puppet::Type.type(:user).provide :netinfo, :parent => Puppet::Provider::NameService::NetInfo do
    desc "User management in NetInfo."
    commands :nireport => "nireport", :niutil => "niutil"

    options :comment, :key => "realname"

    defaultfor :operatingsystem => :darwin

    # The list of all groups the user is a member of.  Different
    # user mgmt systems will need to override this method.
    def groups
        groups = []

        user = @model[:name]
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
        groups = groups.split(/\s*,\s*/)
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

        user = @model[:name]
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

    def setuserlist(group, list)
        cmd = "#{command(:niutil)} -createprop / /groups/%s users %s" %
            [group, list.join(",")]
        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure
            raise Puppet::Error,
                "Failed to set groups: %s" % output
        end
    end
end

# $Id$
