# A module to collect utility functions.

module Puppet
module Util
    # Execute a block as a given user or group
    def self.asuser(user = nil, group = nil)
        require 'etc'

        uid = nil
        gid = nil
        olduid = nil
        oldgid = nil

        begin
            # the groupid, if we got passed a group
            # The gid has to be changed first, because, well, otherwise we won't
            # be able to
            if group
                if group.is_a?(Integer)
                    gid = group
                else
                    unless obj = Puppet.type(:group)[group]
                        obj = Puppet.type(:group).create(
                            :name => group,
                            :check => [:gid]
                        )
                    end
                    obj.retrieve
                    gid = obj.is(:gid)
                    unless gid.is_a?(Integer)
                        raise Puppet::Error, "Could not find group %s" % group
                    end
                end

                if Process.gid != gid
                    oldgid = Process.gid
                    begin
                        Process.egid = gid
                    rescue => detail
                        raise Puppet::Error, "Could not change GID: %s" % detail
                    end
                end
            end

            if user
                # Retrieve the user id
                if user.is_a?(Integer)
                    uid = user
                else
                    unless obj = Puppet.type(:user)[user]
                        obj = Puppet.type(:user).create(
                            :name => user,
                            :check => [:uid, :gid]
                        )
                    end
                    obj.retrieve
                    uid = obj.is(:uid)
                    unless uid.is_a?(Integer)
                        raise Puppet::Error, "Could not find user %s" % user
                    end
                end

                # Now change the uid
                if Process.uid != uid
                    olduid = Process.uid
                    begin
                        Process.euid = uid
                    rescue => detail
                        raise Puppet::Error, "Could not change UID: %s" % detail
                    end
                end
            end

            retval = yield
        ensure
            if olduid
                Process.euid = olduid
            end

            if oldgid
                Process.egid = oldgid
            end
        end

        return retval
    end

    # Create a lock file while something is happening
    def self.lock(*opts)
        lock = opts[0] + ".lock"
        while File.exists?(lock)
            stamp = File.stat(lock).mtime.to_i 
            if Time.now.to_i - stamp > 5
                Puppet.notice "Lock file %s is %s seconds old; removing"
                File.delete(lock)
            end
            #Puppet.debug "%s is locked" % opts[0]
            sleep 0.1
        end
        File.open(lock, "w") { |f| f.print " "; f.flush }
        writing = false
        if opts[1] == "w"
            writing = true
            tmp = opts[0] + ".tmp"
            orig = opts[0]
            opts[0] = tmp
        end
        begin
            File.open(*opts) { |file| yield file }
            if writing
                File.rename(tmp, orig)
            end
        rescue => detail
            Puppet.err "Storage error: %s" % detail
            raise
        ensure
            # I don't really understand how the lock file could disappear,
            # but just in case...
            if FileTest.exists?(lock)
                File.delete(lock)
            end
        end
    end

    # Create instance methods for each of the log levels.  This allows
    # the messages to be a little richer.  Most classes will be calling this
    # method.
    def self.logmethods(klass, useself = true)
        Puppet::Log.eachlevel { |level|
            klass.send(:define_method, level, proc { |args|
                if args.is_a?(Array)
                    args = args.join(" ")
                end
                if useself
                    Puppet::Log.create(
                        :level => level,
                        :source => self,
                        :message => args
                    )
                else
                    Puppet::Log.create(
                        :level => level,
                        :message => args
                    )
                end
            })
        }
    end

    # XXX this should all be done using puppet objects, not using
    # normal mkdir
    def self.recmkdir(dir,mode = 0755)
        if FileTest.exist?(dir)
            return false
        else
            tmp = dir.sub(/^\//,'')
            path = [File::SEPARATOR]
            tmp.split(File::SEPARATOR).each { |dir|
                path.push dir
                if ! FileTest.exist?(File.join(path))
                    Dir.mkdir(File.join(path), mode)
                elsif FileTest.directory?(File.join(path))
                    next
                else FileTest.exist?(File.join(path))
                    raise "Cannot create %s: basedir %s is a file" %
                        [dir, File.join(path)]
                end
            }
            return true
        end
    end

    def self.symbolize(value)
        case value
        when String: value = value.intern
        when Symbol: # nothing
        else
            raise ArgumentError, "'%s' must be a string or symbol" % value
        end
    end
end
end

# $Id$
