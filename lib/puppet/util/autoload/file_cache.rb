module Puppet::Util::Autoload::FileCache
    @found_files = {}
    @missing_files = {}
    class << self
        attr_reader :found_files, :missing_files
    end

    # Only used for testing.
    def self.clear
        @found_files.clear
        @missing_files.clear
    end

    def found_files
        Puppet::Util::Autoload::FileCache.found_files
    end

    def missing_files
        Puppet::Util::Autoload::FileCache.missing_files
    end

    def directory_exist?(path)
        cache = cached_data?(path, :directory?)
        return cache unless cache.nil?

        protect(path) do
            stat = File.lstat(path)
            if stat.directory?
                found_file(path, stat)
                return true
            else
                missing_file(path)
                return false
            end
        end
    end

    def file_exist?(path)
        cache = cached_data?(path)
        return cache unless cache.nil?

        protect(path) do
            stat = File.lstat(path)
            found_file(path, stat)
            return true
        end
    end

    def found_file?(path, type = nil)
        if data = found_files[path] and ! data_expired?(data[:time])
            if type and ! data[:stat].send(type)
                return false
            end
            return true
        else
            return false
        end
    end

    def found_file(path, stat)
        found_files[path] = {:stat => stat, :time => Time.now}
    end

    def missing_file?(path)
        if time = missing_files[path] and ! data_expired?(time)
            return true
        else
            return false
        end
    end

    def missing_file(path)
        missing_files[path] = Time.now
    end

    def named_file_missing?(name)
        @named_files ||= {}
        if time = @named_files[name] and ! data_expired?(time)
            return true
        end
        false
    end

    def named_file_is_missing(name)
        @named_files ||= {}
        @named_files[name] = Time.now
        false
    end

    private

    def cached_data?(path, type = nil)
        if found_file?(path, type)
            return true
        elsif missing_file?(path)
            return false
        else
            return nil
        end
    end

    def data_expired?(time)
        Time.now - time > 15
    end

    def protect(path)
        begin
            yield
        rescue => detail
            raise unless detail.class.to_s.include?("Errno")
            missing_file(path)
            return false
        end
    end
end
