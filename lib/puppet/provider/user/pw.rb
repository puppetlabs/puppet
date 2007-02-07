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
        @model.class.validproperties.each do |property|
            next if property == :ensure
            # the value needs to be quoted, mostly because -c might
            # have spaces in it
            if value = @model.should(property) and value != ""
                cmd << flag(property) << value
            end
        end

        if @model[:allowdupe] == :true
            cmd << "-o"
        end

        return cmd
    end
end

# $Id$
