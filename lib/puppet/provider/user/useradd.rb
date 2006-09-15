require 'puppet/provider/nameservice/objectadd'

Puppet::Type.type(:user).provide :useradd, :parent => Puppet::Provider::NameService::ObjectAdd do
    desc "User management via ``useradd`` and its ilk."

    commands :add => "useradd", :delete => "userdel", :modify => "usermod"

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
        cmd = [command(:add)]
        @model.class.validstates.each do |state|
            next if state == :ensure
            # the value needs to be quoted, mostly because -c might
            # have spaces in it
            if value = @model.should(state) and value != ""
                cmd << flag(state) << "'%s'" % value
            end
        end
        # stupid fedora
        case Facter["operatingsystem"].value
        when "Fedora", "RedHat":
            cmd << "-M"
        else
        end
        if @model[:allowdupe]  == :true
            cmd << "-o"
        end

        cmd << @model[:name]

        cmd.join(" ")
    end
end

# $Id$
