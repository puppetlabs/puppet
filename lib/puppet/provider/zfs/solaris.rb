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

    def arrayify_second_line_on_whitespace(text)
        if second_line = text.split("\n")[1]
            second_line.split("\s")
        else
            []
        end
    end

    def create
        zfs *([:create] + add_properties + [@resource[:name]])
    end

    def delete
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
            #special knowledge of format
            #the command returns values in this format with the header
            #NAME PROPERTY VALUE SOURCE
            arrayify_second_line_on_whitespace(zfs(:get, field, @resource[:name]))[2]
        end

        define_method(field.to_s + "=") do |should|
            zfs(:set, "#{field}=#{should}", @resource[:name])
        end
    end

end

