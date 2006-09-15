module PuppetTestSupport
    module Helpers
        def nonrootuser
            Etc.passwd { |user|
                if user.uid != Process.uid and user.uid > 0
                    return user
                end
            }
        end

        def nonrootgroup
            Etc.group { |group|
                if group.gid != Process.gid and group.gid > 0
                    return group
                end
            }
        end

        def cleanup(&block)
            @@cleaners << block
        end

        def tempfile
            if defined? @@tmpfilenum
                @@tmpfilenum += 1
            else
                @@tmpfilenum = 1
            end

            f = File.join(self.tmpdir(), self.class.to_s + "_" + @method_name +
                          @@tmpfilenum.to_s)
            @@tmpfiles << f
            return f
        end

        def tstdir
            tempfile()
        end

        def tmpdir
            unless defined? @tmpdir and @tmpdir
                @tmpdir = case Facter["operatingsystem"].value
                          when "Darwin": "/private/tmp"
                          when "SunOS": "/var/tmp"
                          else
                "/tmp"
                          end


                @tmpdir = File.join(@tmpdir, "puppettesting")

                unless File.exists?(@tmpdir)
                    FileUtils.mkdir_p(@tmpdir)
                    File.chmod(01777, @tmpdir)
                end
            end
            @tmpdir
        end
    end
end
