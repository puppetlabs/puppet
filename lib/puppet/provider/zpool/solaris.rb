Puppet::Type.type(:zpool).provide(:solaris) do
    desc "Provider for Solaris zpool."

    commands :zpool => "/usr/sbin/zpool"
    defaultfor :operatingsystem => :solaris

    def process_zpool_data(pool_array)
        if pool_array == []
            return Hash.new(:absent)
        end
        #get the name and get rid of it
        pool = Hash.new
        pool[:pool] = pool_array[0]
        pool_array.shift

        tmp = []

        #order matters here :(
        pool_array.reverse.each do |value|
            sym = nil
            case value
            when "spares"; sym = :spare
            when "logs"; sym = :log
            when "mirror", "raidz1", "raidz2"
                sym = value == "mirror" ? :mirror : :raidz
                pool[:raid_parity] = "raidz2" if value == "raidz2"
            else
                tmp << value
                sym = :disk if value == pool_array.first
            end

            if sym
                pool[sym] = pool[sym] ? pool[sym].unshift(tmp.reverse.join(' ')) : [tmp.reverse.join(' ')]
                tmp.clear
            end
        end

        pool
    end

    def get_pool_data
        #this is all voodoo dependent on the output from zpool
        zpool_data = %x{ zpool status #{@resource[:pool]}}.split("\n").select { |line| line.index("\t") == 0 }.collect { |l| l.strip.split("\s")[0] }
        zpool_data.shift
        zpool_data
    end

    def current_pool
        unless (defined?(@current_pool) and @current_pool)
            @current_pool = process_zpool_data(get_pool_data)
        end
        @current_pool
    end

    def flush
        @current_pool= nil
    end

    #Adds log and spare
    def build_named(name)
        if prop = @resource[name.intern]
            [name] + prop.collect { |p| p.split(' ') }.flatten
        else
            []
        end
    end

    #query for parity and set the right string
    def raidzarity
        @resource[:raid_parity] ? @resource[:raid_parity] : "raidz1"
    end

    #handle mirror or raid
    def handle_multi_arrays(prefix, array)
        array.collect{ |a| [prefix] +  a.split(' ') }.flatten
    end

    #builds up the vdevs for create command
    def build_vdevs
        if disk = @resource[:disk]
            disk.collect { |d| d.split(' ') }.flatten
        elsif mirror = @resource[:mirror]
            handle_multi_arrays("mirror", mirror)
        elsif raidz = @resource[:raidz]
            handle_multi_arrays(raidzarity, raidz)
        end
    end

    def create
        zpool(*([:create, @resource[:pool]] + build_vdevs + build_named("spare") + build_named("log")))
    end

    def delete
        zpool :destroy, @resource[:pool]
    end

    def exists?
        if current_pool[:pool] == :absent
            false
        else
            true
        end
    end

    [:disk, :mirror, :raidz, :log, :spare].each do |field|
        define_method(field) do
            current_pool[field]
        end

        define_method(field.to_s + "=") do |should|
            Puppet.warning "NO CHANGES BEING MADE: zpool %s does not match, should be '%s' currently is '%s'" % [field, should, current_pool[field]]
        end
    end

end

