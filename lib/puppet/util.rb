# A module to collect utility functions.

require 'sync'
require 'puppet/lock'

module Puppet
module Util
    # Create a sync point for any threads
    @@sync = Sync.new
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
                gid = self.gid(group)

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
                uid = self.uid(user)
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

    # Change the process to a different user
    def self.chuser
        if group = Puppet[:group]
            group = self.gid(group)
            unless Process.gid == group
                begin
                    Process.egid = group 
                    Process.gid = group 
                rescue
                    $stderr.puts "could not change to group %s" % group
                    exit(74)
                end
            end
        end

        if user = Puppet[:user]
            user = self.uid(user)
            unless Process.uid == user
                begin
                    Process.euid = user 
                    Process.uid = user 
                rescue
                    $stderr.puts "could not change to user %s" % user
                    exit(74)
                end
            end
        end
    end

    # Create a shared lock for reading
    def self.readlock(file)
        @@sync.synchronize(Sync::SH) do
            File.open(file) { |f|
                f.lock_shared { |lf| yield lf }
            }
        end
    end

    # Create an exclusive lock fro writing, and do the writing in a
    # tmp file.
    def self.writelock(file, mode = 0600)
        tmpfile = file + ".tmp"
        @@sync.synchronize(Sync::EX) do
            File.open(file, "w", mode) do |rf|
                rf.lock_exclusive do |lrf|
                    yield lrf
                    File.open(tmpfile, "w", mode) do |tf|
                        yield tf
                        tf.flush
                    end
                    begin
                        File.rename(tmpfile, file)
                    rescue => detail
                        Puppet.err "Could not rename %s to %s: %s" %
                            [file, tmpfile, detail]
                    end
                end
            end
        end
    end

    # Get the GID of a given group, provided either a GID or a name
    def self.gid(group)
        if group =~ /^\d+$/
            group = Integer(group)
        end
        unless group
            raise Puppet::DevError, "Invalid group %s" % group.inspect
        end
        gid = nil
        obj = nil

        # We want to look the group up either way
        if group.is_a?(Integer)
            obj = Puppet.type(:group).find { |gobj|
                gobj.should(:gid) == group ||
                    gobj.is(:gid) == group
            }
        else
            unless obj = Puppet.type(:group)[group]
                obj = Puppet.type(:group).create(
                    :name => group,
                    :check => [:gid]
                )
                obj.retrieve
            end
        end
        if obj
            gid = obj.should(:gid) || obj.is(:gid)
        end

        return gid
    end

    # Get the UID of a given user, whether a UID or name is provided
    def self.uid(user)
        uid = nil
        if user =~ /^\d+$/
            user = Integer(user)
        end
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

        return uid
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
