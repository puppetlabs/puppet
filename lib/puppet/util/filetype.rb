# Basic classes for reading, writing, and emptying files.  Not much
# to see here.

require 'puppet/util/selinux'

class Puppet::Util::FileType
    attr_accessor :loaded, :path, :synced

    include Puppet::Util::SELinux

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
        # Back the file up before replacing it.
        def backup
            bucket.backup(@path) if File.exists?(@path)
        end

        # Read the file.
        def read
            if File.exist?(@path)
                File.read(@path)
            else
                return nil
            end
        end

        # Remove the file.
        def remove
            if File.exist?(@path)
                File.unlink(@path)
            end
        end

        # Overwrite the file.
        def write(text)
            require "tempfile"
            tf = Tempfile.new("puppet")
            tf.print text; tf.flush
            FileUtils.cp(tf.path, @path)
            tf.close
            # If SELinux is present, we need to ensure the file has its expected context
            set_selinux_default_context(@path)
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
                raise Puppet::Error, "User %s not authorized to use cron" % @path if output.include?("you are not authorized to use cron")
                return output
            rescue => detail
                raise Puppet::Error, "Could not read crontab for %s: %s" % [@path, detail]
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

    #  Support for AIX crontab with output different than suntab's crontab command.
    newfiletype(:aixtab) do
        # Read a specific @path's cron tab.
        def read
            begin
                output = Puppet::Util.execute(%w{crontab -l}, :uid => @path)
                if output.include?("You are not authorized to use the cron command")
                    raise Puppet::Error, "User %s not authorized to use cron" % @path 
                end
                return output
            rescue => detail
                raise Puppet::Error, "Could not read crontab for %s: %s" % [@path, detail]
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
            ensure
                output_file.delete
            end
        end
    end
end
