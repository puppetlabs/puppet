require 'puppet/provider/nameservice/pw'

Puppet::Type.type(:user).provide :pw, :parent => Puppet::Provider::NameService::PW do
    desc "User management via ``pw`` on FreeBSD."

    commands :pw => "pw"

    defaultfor :operatingsystem => :freebsd

    options :home, :flag => "-d", :method => :dir
    options :comment, :method => :gecos
    options :groups, :flag => "-G"

    verify :gid, "GID must be an integer" do |value|
        value.is_a? Integer
    end

    verify :groups, "Groups must be comma-separated" do |value|
        value !~ /\s/
    end

    def addcmd
        cmd = [command(:pw), "useradd", @model[:name]]
        @model.class.validstates.each do |state|
            next if name == :ensure
            # the value needs to be quoted, mostly because -c might
            # have spaces in it
            if value = @model[state] and value != ""
                cmd << flag(state) << "'%s'" % @model[state]
            end
        end

        if @model[:allowdupe] == :true
            cmd << "-o"
        end

        return cmd.join(" ")
    end
end

# $Id$
