module Puppet # :nodoc:
    # Basic classes for reading, writing, and emptying files.  Not much
    # to see here.
    class FileType
        attr_accessor :loaded, :path, :synced

        class << self
            attr_accessor :name
        end

        def self.inspect
            "SvcType(#{self.name})"
        end

        def self.to_s
            "SvcType(#{self.name})"
        end

        def svctype
            self.class.name
        end

        def self.newfiletype(name, &block)
            @filetypes ||= {}

            klass = Class.new(self)

            klass.name = name

            klass.class_eval(&block)

            const_set(name.to_s.capitalize, klass)

            # Rename the read and write methods, so that we're sure they
            # maintain the stats.
            klass.class_eval do
                # Rename the read method
                define_method(:real_read, instance_method(:read))
                define_method(:read) do
                    begin
                        val = real_read()
                        @loaded = Time.now
                        return val.gsub(/# HEADER.*\n/,'')
                    rescue Puppet::Error => detail
                        raise
                    rescue => detail
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

            @filetypes[name] = klass
        end

        def self.filetype(type)
            @filetypes[type]
        end

        def initialize(path)
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
                File.open(@path, "w") { |f| f.print text; f.flush }
            end
        end

        # Operate on plain files.
        newfiletype(:ram) do
            def initialize(path)
                super
                @text = ""
            end

            # Read the file.
            def read
                Puppet.info "Reading %s" % @path
                @text
            end

            # Remove the file.
            def remove
                Puppet.info "Removing %s" % @path
                @text = ""
            end

            # Overwrite the file.
            def write(text)
                Puppet.info "Writing %s" % @path
                @text = text
            end
        end

        # Handle Linux-style cron tabs.
        newfiletype(:crontab) do
            # Only add the -u flag when the @path is different.  Fedora apparently
            # does not think I should be allowed to set the @path to my
            def cmdbase
                uid = CronType.uid(@path)
                cmd = nil
                if uid == Process.uid
                    return "crontab"
                else
                    return "crontab -u #{@path}"
                end
            end

            # Read a specific @path's cron tab.
            def read
                %x{#{cmdbase(@path)} -l 2>/dev/null}
            end

            # Remove a specific @path's cron tab.
            def remove
                %x{#{cmdbase(@path)} -r 2>/dev/null}
            end

            # Overwrite a specific @path's cron tab; must be passed the @path name
            # and the text with which to create the cron tab.
            def write(text)
                IO.popen("#{cmdbase(@path)} -", "w") { |p|
                    p.print text
                }
            end
        end

        # SunOS has completely different cron commands; this class implements
        # its versions.
        newfiletype(:suntab) do
            # Read a specific @path's cron tab.
            def read
                Puppet::Util.asuser(@path) {
                    %x{crontab -l 2>/dev/null}
                }
            end

            # Remove a specific @path's cron tab.
            def remove
                Puppet.asuser(@path) {
                    %x{crontab -r 2>/dev/null}
                }
            end

            # Overwrite a specific @path's cron tab; must be passed the @path name
            # and the text with which to create the cron tab.
            def write(text)
                Puppet.asuser(@path) {
                    IO.popen("crontab", "w") { |p|
                        p.print text
                    }
                }
            end
        end
    end
end

# $Id$
