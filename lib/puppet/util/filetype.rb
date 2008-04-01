# Basic classes for reading, writing, and emptying files.  Not much
# to see here.
class Puppet::Util::FileType
    attr_accessor :loaded, :path, :synced

    class << self
        attr_accessor :name
        include Puppet::Util::ClassGen
    end

    # Create a new filetype.
    def self.newfiletype(name, &block)
        @filetypes ||= {}

        klass = genclass(name,
            :block => block,
            :prefix => "FileType",
            :hash => @filetypes
        )

        # Rename the read and write methods, so that we're sure they
        # maintain the stats.
        klass.class_eval do
            # Rename the read method
            define_method(:real_read, instance_method(:read))
            define_method(:read) do
                begin
                    val = real_read()
                    @loaded = Time.now
                    if val
                        return val.gsub(/# HEADER.*\n/,'')
                    else
                        return ""
                    end
                rescue Puppet::Error => detail
                    raise
                rescue => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    raise Puppet::Error, "%s could not read %s: %s" %
                        [self.class, @path, detail]
                end
            end

            # And then the write method
            define_method(:real_write, instance_method(:write))
            define_method(:write) do |text|
                begin
                    val = real_write(text)
                    @synced = Time.now
                    return val
                rescue Puppet::Error => detail
                    raise
                rescue => detail
                    if Puppet[:debug]
                        puts detail.backtrace
                    end
                    raise Puppet::Error, "%s could not write %s: %s" %
                        [self.class, @path, detail]
                end
            end
        end
    end

    def self.filetype(type)
        @filetypes[type]
    end

    # Back the file up before replacing it.
    def backup
        bucket.backup(@path) if FileTest.exists?(@path)
    end

    # Pick or create a filebucket to use.
    def bucket
        unless defined?(@bucket)
            @bucket = Puppet::Type.type(:filebucket).mkdefaultbucket.bucket
        end
        @bucket
    end

    def initialize(path)
        raise ArgumentError.new("Path is nil") if path.nil?
        @path = path
    end

    # Operate on plain files.
    newfiletype(:flat) do
        # Read the file.
        def read
            if File.exists?(@path)
                File.read(@path)
            else
                return nil
            end
        end

        # Remove the file.
        def remove
            if File.exists?(@path)
                File.unlink(@path)
            end
        end

        # Overwrite the file.
        def write(text)
            backup()

            raise("Cannot create file %s in absent directory" % @path) unless FileTest.exist?(File.dirname(@path))

            require "tempfile"
            tf = Tempfile.new("puppet") 
            tf.print text; tf.flush 
            FileUtils.cp(tf.path, @path) 
            tf.close
        end
    end

    # Operate on plain files.
    newfiletype(:ram) do
        @@tabs = {}

        def self.clear
            @@tabs.clear
        end

        def initialize(path)
            super
            @@tabs[@path] ||= ""
        end

        # Read the file.
        def read
            Puppet.info "Reading %s from RAM" % @path
            @@tabs[@path]
        end

        # Remove the file.
        def remove
            Puppet.info "Removing %s from RAM" % @path
            @@tabs[@path] = ""
        end

        # Overwrite the file.
        def write(text)
            Puppet.info "Writing %s to RAM" % @path
            @@tabs[@path] = text
        end
    end

    # Handle Linux-style cron tabs.
    newfiletype(:crontab) do
        def initialize(user)
            self.path = user
        end

        def path=(user)
            begin
                @uid = Puppet::Util.uid(user)
            rescue Puppet::Error => detail
                raise Puppet::Error, "Could not retrieve user %s" % user
            end

            # XXX We have to have the user name, not the uid, because some
            # systems *cough*linux*cough* require it that way
            @path = user
        end

        # Read a specific @path's cron tab.
        def read
            %x{#{cmdbase()} -l 2>/dev/null}
        end

        # Remove a specific @path's cron tab.
        def remove
            if %w{Darwin FreeBSD}.include?(Facter.value("operatingsystem"))
                %x{/bin/echo yes | #{cmdbase()} -r 2>/dev/null}
            else
                %x{#{cmdbase()} -r 2>/dev/null}
            end
        end

        # Overwrite a specific @path's cron tab; must be passed the @path name
        # and the text with which to create the cron tab.
        def write(text)
            IO.popen("#{cmdbase()} -", "w") { |p|
                p.print text
            }
        end

        private

        # Only add the -u flag when the @path is different.  Fedora apparently
        # does not think I should be allowed to set the @path to my own user name
        def cmdbase
            cmd = nil
            if @uid == Puppet::Util::SUIDManager.uid
                return "crontab"
            else
                return "crontab -u #{@path}"
            end
        end
    end

    # SunOS has completely different cron commands; this class implements
    # its versions.
    newfiletype(:suntab) do
        # Read a specific @path's cron tab.
        def read
            begin
                output = Puppet::Util.execute(%w{crontab -l}, :uid => @path)
                return "" if output.include?("can't open your crontab")
                return output
            rescue
                # If there's a failure, treat it like an empty file.
                return ""
            end
        end

        # Remove a specific @path's cron tab.
        def remove
            begin
                Puppet::Util.execute(%w{crontab -r}, :uid => @path)
            rescue => detail
                raise Puppet::Error, "Could not remove crontab for %s: %s" % [@path, detail]
            end
        end

        # Overwrite a specific @path's cron tab; must be passed the @path name
        # and the text with which to create the cron tab.
        def write(text)
            puts text
            require "tempfile"
            output_file = Tempfile.new("puppet")
            fh = output_file.open
            fh.print text
            fh.close

            # We have to chown the stupid file to the user.
            File.chown(Puppet::Util.uid(@path), nil, output_file.path)

            begin
                Puppet::Util.execute(["crontab", output_file.path], :uid => @path)
            rescue => detail
                raise Puppet::Error, "Could not write crontab for %s: %s" % [@path, detail]
            end
            output_file.delete
        end
    end

    # Treat netinfo tables as a single file, just for simplicity of certain
    # types
    newfiletype(:netinfo) do
        class << self
            attr_accessor :format
        end
        def read
            %x{nidump -r /#{@path} /}
        end

        # This really only makes sense for cron tabs.
        def remove
            %x{nireport / /#{@path} name}.split("\n").each do |name|
                newname = name.gsub(/\//, '\/').sub(/\s+$/, '')
                output = %x{niutil -destroy / '/#{@path}/#{newname}'}

                unless $? == 0
                    raise Puppet::Error, "Could not remove %s from %s" %
                        [name, @path]
                end
            end
        end

        # Convert our table to an array of hashes.  This only works for
        # handling one table at a time.
        def to_array(text = nil)
            unless text
                text = read
            end

            hash = nil

            # Initialize it with the first record
            records = []
            text.split("\n").each do |line|
                next if line =~ /^[{}]$/ # Skip the wrapping lines
                next if line =~ /"name" = \( "#{@path}" \)/ # Skip the table name
                next if line =~ /CHILDREN = \(/ # Skip this header
                next if line =~ /^  \)/ # and its closer

                # Now we should have nothing but records, wrapped in braces

                case line
                when /^\s+\{/: hash = {}
                when /^\s+\}/: records << hash
                when /\s+"(\w+)" = \( (.+) \)/
                    field = $1
                    values = $2

                    # Always use an array
                    hash[field] = []

                    values.split(/, /).each do |value|
                        if value =~ /^"(.*)"$/
                            hash[field] << $1
                        else
                            raise ArgumentError, "Could not match value %s" % value
                        end
                    end
                else    
                    raise ArgumentError, "Could not match line %s" % line
                end
            end

            records
        end

        def write(text)
            text.gsub!(/^#.*\n/,'')
            text.gsub!(/^$/,'')
            if text == "" or text == "\n"
                self.remove
                return
            end
            unless format = self.class.format
                raise Puppe::DevError, "You must define the NetInfo format to inport"
            end
            IO.popen("niload -d #{format} . 1>/dev/null 2>/dev/null", "w") { |p|
                p.print text
            }

            unless $? == 0
                raise ArgumentError, "Failed to write %s" % @path
            end
        end
    end
end

