# A module to collect utility functions.

require 'sync'
require 'puppet/external/lock'

module Puppet
    # A command failed to execute.
    class ExecutionFailure < Puppet::Error
    end
module Util
    require 'benchmark'
    
    require 'puppet/util/posix'
    extend Puppet::Util::POSIX

    # Create a hash to store the different sync objects.
    @@syncresources = {}

    # Return the sync object associated with a given resource.
    def self.sync(resource)
        @@syncresources[resource] ||= Sync.new
        return @@syncresources[resource]
    end

    # Change the process to a different user
    def self.chuser
        if Facter["operatingsystem"].value == "Darwin"
            $stderr.puts "Ruby on darwin is broken; puppetmaster will not set its UID to 'puppet' and must run as root"
            return
        end
        if group = Puppet[:group]
            group = self.gid(group)
            unless group
                raise Puppet::Error, "No such group %s" % Puppet[:group]
            end
            unless Puppet::SUIDManager.gid == group
                begin
                    Puppet::SUIDManager.egid = group 
                    Puppet::SUIDManager.gid = group 
                rescue => detail
                    Puppet.warning "could not change to group %s: %s" %
                        [group.inspect, detail]
                    $stderr.puts "could not change to group %s" % group.inspect

                    # Don't exit on failed group changes, since it's
                    # not fatal
                    #exit(74)
                end
            end
        end

        if user = Puppet[:user]
            user = self.uid(user)
            unless user
                raise Puppet::Error, "No such user %s" % Puppet[:user]
            end
            unless Puppet::SUIDManager.uid == user
                begin
                    Puppet::SUIDManager.uid = user 
                    Puppet::SUIDManager.euid = user 
                rescue
                    $stderr.puts "could not change to user %s" % user
                    exit(74)
                end
            end
        end
    end

    # Create a shared lock for reading
    def self.readlock(file)
        self.sync(file).synchronize(Sync::SH) do
            File.open(file) { |f|
                f.lock_shared { |lf| yield lf }
            }
        end
    end

    # Create an exclusive lock for writing, and do the writing in a
    # tmp file.
    def self.writelock(file, mode = 0600)
        tmpfile = file + ".tmp"
        unless FileTest.directory?(File.dirname(tmpfile))
            raise Puppet::DevError, "Cannot create %s; directory %s does not exist" %
                [file, File.dirname(file)]
        end
        self.sync(file).synchronize(Sync::EX) do
            File.open(file, "w", mode) do |rf|
                rf.lock_exclusive do |lrf|
                    File.open(tmpfile, "w", mode) do |tf|
                        yield tf
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

    # Proxy a bunch of methods to another object.
    def self.classproxy(klass, objmethod, *methods)
        classobj = class << klass; self; end
        methods.each do |method|
            classobj.send(:define_method, method) do |*args|
                obj = self.send(objmethod)

                obj.send(method, *args)
            end
        end
    end

    # Proxy a bunch of methods to another object.
    def self.proxy(klass, objmethod, *methods)
        methods.each do |method|
            klass.send(:define_method, method) do |*args|
                obj = self.send(objmethod)

                obj.send(method, *args)
            end
        end
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
            if respond_to?(level)
                object = self
            else
                object = Puppet
            end
        else
            object = args.pop
        end

        unless level
            raise Puppet::DevError, "Failed to provide level to :benchmark"
        end

        unless object.respond_to? level
            raise Puppet::DevError, "Benchmarked object does not respond to %s" % level
        end

        # Only benchmark if our log level is high enough
        if level != :none and Puppet::Log.sendlevel?(level)
            result = nil
            seconds = Benchmark.realtime {
                yield
            }
            object.send(level, msg + (" in %0.2f seconds" % seconds))
            return seconds
        else
            yield
        end
    end

    def binary(bin)
        if bin =~ /^\//
            if FileTest.exists? bin
                return true
            else
                return nil
            end
        else
            ENV['PATH'].split(":").each do |dir|
                if FileTest.exists? File.join(dir, bin)
                    return File.join(dir, bin)
                end
            end
            return nil
        end
    end
    module_function :binary

    # Execute the provided command in a pipe, yielding the pipe object.
    def execpipe(command, failonfail = true)
        if respond_to? :debug
            debug "Executing '%s'" % command
        else
            Puppet.debug "Executing '%s'" % command
        end

        output = open("| #{command} 2>&1") do |pipe|
            yield pipe
        end

        if failonfail
            unless $? == 0
                raise ExecutionFailure, output
            end
        end

        return output
    end

    def execfail(command, exception)
        begin
            output = execute(command)
            return output
        rescue ExecutionFailure
            raise exception, output
        end
    end

    # Execute the desired command, and return the status and output.
    def execute(command, failonfail = true, uid = nil, gid = nil)
        if command.is_a?(Array)
            command = command.flatten.collect { |i| i.to_s }
            str = command.join(" ")
        else
            # We require an array here so we know where we're incorrectly
            # using a string instead of an array.  Once everything is
            # switched to an array, we might relax this requirement.
            raise ArgumentError, "Must pass an array to execute()"
        end

        if respond_to? :debug
            debug "Executing '%s'" % str
        else
            Puppet.debug "Executing '%s'" % str
        end
        
        if uid
            uid = Puppet::SUIDManager.convert_xid(:uid, uid)
        end
        if gid
            gid = Puppet::SUIDManager.convert_xid(:gid, gid)
        end
        
        @@os ||= Facter.value(:operatingsystem)
        output = nil
        IO.popen("-") do |f|
            if f
                output = f.read
            else
                # FIXME There really should be a better way to do this,
                # but it looks like webrick is already setting close_on_exec,
                # and setting it myself doesn't seem to do anything.  So,
                # not the best, but it'll have to do.
                if Puppet[:listen]
                    ObjectSpace.each_object do |object|
                        if object.is_a?(TCPServer) and ! object.closed?
                            begin
                                object.close
                            rescue
                                # Just ignore these, I guess
                            end
                        end
                    end
                end
                begin
                    $stderr.close
                    $stderr = $stdout.dup
                    if gid
                        Process.egid = gid
                        Process.gid = gid unless @@os == "Darwin"
                    end
                    if uid
                        Process.euid = uid
                        Process.uid = uid unless @@os == "Darwin"
                    end
                    if command.is_a?(Array)
                        system(*command)
                    else
                        system(command)
                    end
                    exit!($?.exitstatus)
                rescue => detail
                    puts detail.to_s
                    exit!(1)
                end
            end
        end

        if failonfail
            unless $? == 0
                raise ExecutionFailure, "Execution of '%s' returned %s: %s" % [str, $?.exitstatus, output]
            end
        end

        return output
    end

    module_function :execute

    # Create an exclusive lock.
    def threadlock(resource, type = Sync::EX)
        Puppet::Util.sync(resource).synchronize(type) do
            yield
        end
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

    def symbolize(value)
        if value.respond_to? :intern
            value.intern
        else
            value
        end
    end

    def symbolizehash(hash)
        newhash = {}
        hash.each do |name, val|
            if name.is_a? String
                newhash[name.intern] = val
            else
                newhash[name] = val
            end
        end
    end

    def symbolizehash!(hash)
        hash.each do |name, val|
            if name.is_a? String
                hash[name.intern] = val
                hash.delete(name)
            end
        end

        return hash
    end
    module_function :symbolize, :symbolizehash, :symbolizehash!

    # Just benchmark, with no logging.
    def thinmark
        seconds = Benchmark.realtime {
            yield
        }

        return seconds
    end

    module_function :memory, :thinmark
end
end

require 'puppet/util/errors'
require 'puppet/util/methodhelper'
require 'puppet/util/metaid'
require 'puppet/util/classgen'
require 'puppet/util/docs'
require 'puppet/util/execution'
require 'puppet/util/logging'
require 'puppet/util/package'
require 'puppet/util/warnings'

# $Id$
