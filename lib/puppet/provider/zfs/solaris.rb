Puppet::Type.type(:zfs).provide(:solaris) do
    desc "Provider for Solaris zfs."

    commands :zfs => "/usr/sbin/zfs"
    defaultfor :operatingsystem => :solaris

    def add_properties
        properties = []
        Puppet::Type.type(:zfs).validproperties.each do |property|
            next if property == :ensure
            if value = @resource[property] and value != ""
                properties << "-o" << "#{property}=#{value}"
            end
        end
        properties
    end

    def create
        zfs *([:create] + add_properties + [@resource[:name]])
    end

    def destroy
        zfs(:destroy, @resource[:name])
    end

    def exists?
        if zfs(:list).split("\n").detect { |line| line.split("\s")[0] == @resource[:name] }
            true
        else
            false
        end
    end

    [:mountpoint, :compression, :copies, :quota, :reservation, :sharenfs, :snapdir].each do |field|
        define_method(field) do
            zfs(:get, "-H", "-o", "value", field, @resource[:name]).strip
        end

        define_method(field.to_s + "=") do |should|
            zfs(:set, "#{field}=#{should}", @resource[:name])
        end
    end

end

