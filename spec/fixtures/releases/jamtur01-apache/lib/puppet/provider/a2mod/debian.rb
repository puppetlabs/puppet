Puppet::Type.type(:a2mod).provide(:debian) do
    desc "Manage Apache 2 modules on Debian-like OSes (e.g. Ubuntu)"

    commands :encmd => "a2enmod"
    commands :discmd => "a2dismod"

    defaultfor :operatingsystem => [:debian, :ubuntu]

    def create
        encmd resource[:name]
    end

    def destroy
        discmd resource[:name]
    end

    def exists?
        mod= "/etc/apache2/mods-enabled/" + resource[:name] + ".load"
        Puppet::FileSystem.exist?(mod)
    end
end
