Puppet::Type.type(:newfile).provide(:default) do
    # Remove the file.
    def destroy
    end

    # Does the file currently exist?
    def exist?
        ! stat.nil?
    end

    def content
        return :absent unless exist?
        begin
            File.read(name)
        rescue => detail
            fail "Could not read %s: %s" % [name, detail]
        end
    end

    def content=(value)
        File.open(name, "w") { |f| f.print value }
    end

    def flush
        @stat = nil
    end

    def group
        return :absent unless exist?
        stat.gid
    end

    def group=(value)
        File.chown(nil, value, name)
    end

    def mkdir
        begin
            Dir.mkdir(name)
        rescue Errno::ENOENT
            fail "Cannot create %s; parent directory does not exist" % name
        rescue => detail
            fail "Could not create directory %s: %s" % [name, detail]
        end
    end

    def mkfile
    end

    def mklink
    end

    def mode
        return :absent unless exist?
        stat.mode & 007777
    end

    def mode=(value)
        File.chmod(value, name)
    end

    def owner
        return :absent unless exist?
        stat.uid
    end

    def owner=(value)
        File.chown(value, nil, name)
    end

    def type
        return :absent unless exist?
        stat.ftype
    end

    private

    def stat
        unless defined?(@stat) and @stat
            begin
                @stat = File.stat(name)
                # Map the property names to the stat values, yo.
            rescue Errno::ENOENT
                @stat = nil
            end
        end
        @stat
    end
end
