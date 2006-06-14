# A module to collect utility functions.

require 'sync'
require 'puppet/lock'

module Puppet
    # A command failed to execute.
    class ExecutionFailure < RuntimeError
    end
module Util
    require 'benchmark'

    # Create a sync point for any threads
    @@sync = Sync.new
    # Execute a block as a given user or group
    def self.asuser(user = nil, group = nil)
        require 'etc'

        uid = nil
        gid = nil
        olduid = nil
        oldgid = nil

        # If they're running as a normal user, then just execute as that same
        # user.
        unless Process.uid == 0
            yield
            return
        end

        begin
            # the groupid, if we got passed a group
            # The gid has to be changed first, because, well, otherwise we won't
            # be able to
            if group
                if group.is_a? Integer
                    gid = group
                else
                    gid = self.gid(group)
                end

                if gid
                    if Process.gid != gid
                        oldgid = Process.gid
                        begin
                            Process.egid = gid
                        rescue => detail
                            raise Puppet::Error, "Could not change GID: %s" % detail
                        end
                    end
                else
                    Puppet.warning "Could not retrieve GID for %s" % group
                end
            end

            if user
                if user.is_a? Integer
                    uid = user
                else
                    uid = self.uid(user)
                end
                uid = self.uid(user)

                if uid
                    # Now change the uid
                    if Process.uid != uid
                        olduid = Process.uid
                        begin
                            Process.euid = uid
                        rescue => detail
                            raise Puppet::Error, "Could not change UID: %s" % detail
                        end
                    end
                else
                    Puppet.warning "Could not retrieve UID for %s" % user
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
            unless group
                raise Puppet::Error, "No such group %s" % Puppet[:group]
            end
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
            unless user
                raise Puppet::Error, "No such user %s" % Puppet[:user]
            end
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
            # If this doesn't find anything
            obj = Puppet.type(:group).find { |gobj|
                gobj.should(:gid) == group ||
                    gobj.is(:gid) == group
            }

            unless obj
                begin
                    gobj = Etc.getgrgid(group)
                    gid = gobj.gid
                rescue ArgumentError => detail
                    # ignore it; we couldn't find the group
                end
            end
        else
            if obj = Puppet.type(:group)[group]
                obj[:check] = [:gid]
            else
                obj = Puppet.type(:group).create(
                    :name => group,
                    :check => [:gid]
                )
            end
            obj.retrieve
        end
        if obj
            gid = obj.should(:gid) || obj.is(:gid)
            if gid == :absent
                gid = nil
            end
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
            # If this doesn't find anything
            obj = Puppet.type(:user).find { |uobj|
                uobj.should(:uid) == user ||
                    uobj.is(:uid) == user
            }

            unless obj
                begin
                    uobj = Etc.getpwuid(user)
                    uid = uobj.uid
                rescue ArgumentError => detail
                    # ignore it; we couldn't find the user
                end
            end
        else
            unless obj = Puppet.type(:user)[user]
                obj = Puppet.type(:user).create(
                    :name => user
                )
            end
            obj[:check] = [:uid, :gid]
        end

        if obj
            obj.retrieve
            uid = obj.should(:uid) || obj.is(:uid)
            if uid == :absent
                uid = nil
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

    # Execute a given chunk of code with a new umask.
    def self.withumask(mask)
        cur = File.umask(mask)

        begin
            yield
        ensure
            File.umask(cur)
        end
    end

    def benchmark(*args)
        msg = args.pop
        level = args.pop
        object = nil

        if args.empty?
            object = Puppet
        else
            object = args.pop
        end

        unless level
            puts caller.join("\n")
            raise Puppet::DevError, "Failed to provide level"
        end

        unless object.respond_to? level
            raise Puppet::DevError, "Benchmarked object does not respond to %s" % level
        end

        # Only benchmark if our log level is high enough
        if Puppet::Log.sendlevel?(level)
            result = nil
            seconds = Benchmark.realtime {
                result = yield
            }
            object.send(level, msg + (" in %0.2f seconds" % seconds))
            result
        else
            yield
        end
    end

    # Execute the desired command, and return the status and output.
    def execute(command, failonfail = true)
        if respond_to? :debug
            debug "Executing '%s'" % command
        else
            Puppet.debug "Executing '%s'" % command
        end
        output = %x{#{command} 2>&1}

        if failonfail
            unless $? == 0
                raise ExecutionFailure, output
            end
        end

        return output
    end

    # Because some modules provide their own version of this method.
    alias util_execute execute

    module_function :benchmark

    def memory
        unless defined? @pmap
            pmap = %x{which pmap 2>/dev/null}.chomp
            if $? != 0 or pmap =~ /^no/
                @pmap = nil
            else
                @pmap = pmap
            end
        end
        if @pmap
            return %x{pmap #{Process.pid}| grep total}.chomp.sub(/^\s*total\s+/, '').sub(/K$/, '').to_i
        else
            0
        end
    end
    module_function :memory
end
end

# $Id$
