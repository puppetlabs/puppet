require 'puppet/provider/nameservice/pw'

Puppet::Type.type(:group).provide :pw, :parent => Puppet::Provider::NameService::PW do
    desc "Group management via ``pw``.  Only works on FreeBSD."

    commands :pw => "/usr/sbin/pw"
    defaultfor :operatingsystem => :freebsd

    verify :gid, "GID must be an integer" do |value|
        value.is_a? Integer
    end

    def addcmd
        cmd = [command(:pw), "groupadd", @model[:name]]
        if gid = @model.should(:gid)
            unless gid == :absent
                cmd << flag(:gid) << "'%s'" % gid
            end
        end

        # Apparently, contrary to the man page, groupadd does
        # not accept -o.
        #if @parent[:allowdupe] == :true
        #    cmd << "-o"
        #end

        return cmd.join(" ")
    end
end

# $Id$
