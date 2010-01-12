# A module to collect utility functions.

require 'puppet/util/monkey_patches'
require 'sync'
require 'puppet/external/lock'

module Puppet
    # A command failed to execute.
    class ExecutionFailure < Puppet::Error
    end
module Util
    require 'benchmark'

    # These are all for backward compatibility -- these are methods that used
    # to be in Puppet::Util but have been moved into external modules.
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
        if group = Puppet[:group]
            group = self.gid(group)
            unless group
                raise Puppet::Error, "No such group %s" % Puppet[:group]
            end
            unless Puppet::Util::SUIDManager.gid == group
                begin
                    Puppet::Util::SUIDManager.egid = group
                    Puppet::Util::SUIDManager.gid = group
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
            unless Puppet::Util::SUIDManager.uid == user
                begin
                    Puppet::Util::SUIDManager.initgroups(user)
                    Puppet::Util::SUIDManager.uid = user
                    Puppet::Util::SUIDManager.euid = user
                rescue => detail
                    $stderr.puts "Could not change to user %s: %s" % [user, detail]
                    exit(74)
                end
            end
        end
    end

    # Create instance methods for each of the log levels.  This allows
    # the messages to be a little richer.  Most classes will be calling this
    # method.
    def self.logmethods(klass, useself = true)
        Puppet::Util::Log.eachlevel { |level|
            klass.send(:define_method, level, proc { |args|
                if args.is_a?(Array)
                    args = args.join(" ")
                end
                if useself
                    Puppet::Util::Log.create(
                        :level => level,
                        :source => self,
                        :message => args
                    )
                else
                    Puppet::Util::Log.create(
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

        unless level == :none or object.respond_to? level
            raise Puppet::DevError, "Benchmarked object does not respond to %s" % level
        end

        # Only benchmark if our log level is high enough
        if level != :none and Puppet::Util::Log.sendlevel?(level)
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
            return bin if FileTest.file? bin and FileTest.executable? bin
        else
           ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
               dest=File.join(dir, bin)
               return dest if FileTest.file? dest and FileTest.executable? dest
           end
        end
        return nil
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
    # def execute(command, failonfail = true, uid = nil, gid = nil)
    # :combine sets whether or not to combine stdout/stderr in the output
    # :stdinfile sets a file that can be used for stdin. Passing a string
    # for stdin is not currently supported.
    def execute(command, arguments = {:failonfail => true, :combine => true})
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

        if arguments[:uid]
            arguments[:uid] = Puppet::Util::SUIDManager.convert_xid(:uid, arguments[:uid])
        end
        if arguments[:gid]
            arguments[:gid] = Puppet::Util::SUIDManager.convert_xid(:gid, arguments[:gid])
        end

        @@os ||= Facter.value(:operatingsystem)
        output = nil
        child_pid, child_status = nil
        # There are problems with read blocking with badly behaved children
        # read.partialread doesn't seem to capture either stdout or stderr
        # We hack around this using a temporary file

        # The idea here is to avoid IO#read whenever possible.
        output_file="/dev/null"
        error_file="/dev/null"
        if ! arguments[:squelch]
            require "tempfile"
            output_file = Tempfile.new("puppet")
            if arguments[:combine]
                error_file=output_file
            end
        end

        oldverb = $VERBOSE
        $VERBOSE = nil
        child_pid = Kernel.fork
        $VERBOSE = oldverb
        if child_pid
            # Parent process executes this
            child_status = (Process.waitpid2(child_pid)[1]).to_i >> 8
        else
            # Child process executes this
            Process.setsid
            begin
                if arguments[:stdinfile]
                    $stdin.reopen(arguments[:stdinfile])
                else
                    $stdin.reopen("/dev/null")
                end
                $stdout.reopen(output_file)
                $stderr.reopen(error_file)

                3.upto(256){|fd| IO::new(fd).close rescue nil}
                if arguments[:gid]
                    Process.egid = arguments[:gid]
                    Process.gid = arguments[:gid] unless @@os == "Darwin"
                end
                if arguments[:uid]
                    Process.euid = arguments[:uid]
                    Process.uid = arguments[:uid] unless @@os == "Darwin"
                end
                ENV['LANG'] = ENV['LC_ALL'] = ENV['LC_MESSAGES'] = ENV['LANGUAGE'] = 'C'
                if command.is_a?(Array)
                    Kernel.exec(*command)
                else
                    Kernel.exec(command)
                end
            rescue => detail
                puts detail.to_s
                exit!(1)
            end # begin; rescue
        end # if child_pid

        # read output in if required
        if ! arguments[:squelch]

            # Make sure the file's actually there.  This is
            # basically a race condition, and is probably a horrible
            # way to handle it, but, well, oh well.
            unless FileTest.exists?(output_file.path)
                Puppet.warning "sleeping"
                sleep 0.5
                unless FileTest.exists?(output_file.path)
                    Puppet.warning "sleeping 2"
                    sleep 1
                    unless FileTest.exists?(output_file.path)
                        Puppet.warning "Could not get output"
                        output = ""
                    end
                end
            end
            unless output
                # We have to explicitly open here, so that it reopens
                # after the child writes.
                output = output_file.open.read

                # The 'true' causes the file to get unlinked right away.
                output_file.close(true)
            end
        end

        if arguments[:failonfail]
            unless child_status == 0
                raise ExecutionFailure, "Execution of '%s' returned %s: %s" % [str, child_status, output]
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

    def secure_open(file,must_be_w,&block)
        raise Puppet::DevError,"secure_open only works with mode 'w'" unless must_be_w == 'w'
        raise Puppet::DevError,"secure_open only requires a block"    unless block_given?
        Puppet.warning "#{file} was a symlink to #{File.readlink(file)}" if File.symlink?(file)
        if File.exists?(file) or File.symlink?(file)
            wait = File.symlink?(file) ? 5.0 : 0.1
            File.delete(file)
            sleep wait # give it a chance to reappear, just in case someone is actively trying something.
        end
        begin
            File.open(file,File::CREAT|File::EXCL|File::TRUNC|File::WRONLY,&block)
        rescue Errno::EEXIST
            desc = File.symlink?(file) ? "symlink to #{File.readlink(file)}" : File.stat(file).ftype
            puts "Warning: #{file} was apparently created by another process (as"
            puts "a #{desc}) as soon as it was deleted by this process.  Someone may be trying"
            puts "to do something objectionable (such as tricking you into overwriting system"
            puts "files if you are running as root)."
            raise
        end
    end
    module_function :secure_open
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
