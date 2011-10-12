# A module to collect utility functions.

require 'English'
require 'puppet/util/monkey_patches'
require 'sync'
require 'tempfile'
require 'puppet/external/lock'
require 'monitor'
require 'puppet/util/execution_stub'
require 'uri'

module Puppet
  # A command failed to execute.
  require 'puppet/error'
  class ExecutionFailure < Puppet::Error
  end
module Util
  require 'benchmark'

  # These are all for backward compatibility -- these are methods that used
  # to be in Puppet::Util but have been moved into external modules.
  require 'puppet/util/posix'
  extend Puppet::Util::POSIX

  @@sync_objects = {}.extend MonitorMixin

  def self.activerecord_version
    if (defined?(::ActiveRecord) and defined?(::ActiveRecord::VERSION) and defined?(::ActiveRecord::VERSION::MAJOR) and defined?(::ActiveRecord::VERSION::MINOR))
      ([::ActiveRecord::VERSION::MAJOR, ::ActiveRecord::VERSION::MINOR].join('.').to_f)
    else
      0
    end
  end

  def self.synchronize_on(x,type)
    sync_object,users = 0,1
    begin
      @@sync_objects.synchronize {
        (@@sync_objects[x] ||= [Sync.new,0])[users] += 1
      }
      @@sync_objects[x][sync_object].synchronize(type) { yield }
    ensure
      @@sync_objects.synchronize {
        @@sync_objects.delete(x) unless (@@sync_objects[x][users] -= 1) > 0
      }
    end
  end

  # Change the process to a different user
  def self.chuser
    if group = Puppet[:group]
      begin
        Puppet::Util::SUIDManager.change_group(group, true)
      rescue => detail
        Puppet.warning "could not change to group #{group.inspect}: #{detail}"
        $stderr.puts "could not change to group #{group.inspect}"

        # Don't exit on failed group changes, since it's
        # not fatal
        #exit(74)
      end
    end

    if user = Puppet[:user]
      begin
        Puppet::Util::SUIDManager.change_user(user, true)
      rescue => detail
        $stderr.puts "Could not change to user #{user}: #{detail}"
        exit(74)
      end
    end
  end

  # Create instance methods for each of the log levels.  This allows
  # the messages to be a little richer.  Most classes will be calling this
  # method.
  def self.logmethods(klass, useself = true)
    Puppet::Util::Log.eachlevel { |level|
      klass.send(:define_method, level, proc { |args|
        args = args.join(" ") if args.is_a?(Array)
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
          raise "Cannot create #{dir}: basedir #{File.join(path)} is a file"
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

    raise Puppet::DevError, "Failed to provide level to :benchmark" unless level

    unless level == :none or object.respond_to? level
      raise Puppet::DevError, "Benchmarked object does not respond to #{level}"
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

  def which(bin)
    if absolute_path?(bin)
      return bin if FileTest.file? bin and FileTest.executable? bin
    else
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
        dest=File.join(dir, bin)
        return dest if FileTest.file? dest and FileTest.executable? dest
      end
    end
    nil
  end
  module_function :which

  # Determine in a platform-specific way whether a path is absolute. This
  # defaults to the local platform if none is specified.
  def absolute_path?(path, platform=nil)
    # Escape once for the string literal, and once for the regex.
    slash = '[\\\\/]'
    name = '[^\\\\/]+'
    regexes = {
      :windows => %r!^(([A-Z]:#{slash})|(#{slash}#{slash}#{name}#{slash}#{name})|(#{slash}#{slash}\?#{slash}#{name}))!i,
      :posix   => %r!^/!,
    }
    require 'puppet'
    platform ||= Puppet.features.microsoft_windows? ? :windows : :posix

    !! (path =~ regexes[platform])
  end
  module_function :absolute_path?

  # Convert a path to a file URI
  def path_to_uri(path)
    return unless path

    params = { :scheme => 'file' }

    if Puppet.features.microsoft_windows?
      path = path.gsub(/\\/, '/')

      if unc = /^\/\/([^\/]+)(\/[^\/]+)/.match(path)
        params[:host] = unc[1]
        path = unc[2]
      elsif path =~ /^[a-z]:\//i
        path = '/' + path
      end
    end

    params[:path] = URI.escape(path)

    begin
      URI::Generic.build(params)
    rescue => detail
      raise Puppet::Error, "Failed to convert '#{path}' to URI: #{detail}"
    end
  end
  module_function :path_to_uri

  # Get the path component of a URI
  def uri_to_path(uri)
    return unless uri.is_a?(URI)

    path = URI.unescape(uri.path)

    if Puppet.features.microsoft_windows? and uri.scheme == 'file'
      if uri.host
        path = "//#{uri.host}" + path # UNC
      else
        path.sub!(/^\//, '')
      end
    end

    path
  end
  module_function :uri_to_path

  # Execute the provided command in a pipe, yielding the pipe object.
  def execpipe(command, failonfail = true)
    if respond_to? :debug
      debug "Executing '#{command}'"
    else
      Puppet.debug "Executing '#{command}'"
    end

    command_str = command.respond_to?(:join) ? command.join('') : command
    output = open("| #{command_str} 2>&1") do |pipe|
      yield pipe
    end

    if failonfail
      unless $CHILD_STATUS == 0
        raise ExecutionFailure, output
      end
    end

    output
  end

  def execfail(command, exception)
      output = execute(command)
      return output
  rescue ExecutionFailure
      raise exception, output
  end

  def execute_posix(command, arguments, stdin, stdout, stderr)
    child_pid = Kernel.fork do
      # We can't just call Array(command), and rely on it returning
      # things like ['foo'], when passed ['foo'], because
      # Array(command) will call command.to_a internally, which when
      # given a string can end up doing Very Bad Things(TM), such as
      # turning "/tmp/foo;\r\n /bin/echo" into ["/tmp/foo;\r\n", " /bin/echo"]
      command = [command].flatten
      Process.setsid
      begin
        $stdin.reopen(stdin)
        $stdout.reopen(stdout)
        $stderr.reopen(stderr)

        3.upto(256){|fd| IO::new(fd).close rescue nil}

        Puppet::Util::SUIDManager.change_group(arguments[:gid], true) if arguments[:gid]
        Puppet::Util::SUIDManager.change_user(arguments[:uid], true)  if arguments[:uid]

        ENV['LANG'] = ENV['LC_ALL'] = ENV['LC_MESSAGES'] = ENV['LANGUAGE'] = 'C'
        Kernel.exec(*command)
      rescue => detail
        puts detail.to_s
        exit!(1)
      end
    end
    child_pid
  end
  module_function :execute_posix

  def execute_windows(command, arguments, stdin, stdout, stderr)
    command = command.map do |part|
      part.include?(' ') ? %Q["#{part.gsub(/"/, '\"')}"] : part
    end.join(" ") if command.is_a?(Array)

    process_info = Process.create( :command_line => command, :startup_info => {:stdin => stdin, :stdout => stdout, :stderr => stderr} )
    process_info.process_id
  end
  module_function :execute_windows

  # Execute the desired command, and return the status and output.
  # def execute(command, failonfail = true, uid = nil, gid = nil)
  # :combine sets whether or not to combine stdout/stderr in the output
  # :stdinfile sets a file that can be used for stdin. Passing a string
  # for stdin is not currently supported.
  def execute(command, arguments = {:failonfail => true, :combine => true})
    if command.is_a?(Array)
      command = command.flatten.map(&:to_s)
      str = command.join(" ")
    elsif command.is_a?(String)
      str = command
    end

    if respond_to? :debug
      debug "Executing '#{str}'"
    else
      Puppet.debug "Executing '#{str}'"
    end

    null_file = Puppet.features.microsoft_windows? ? 'NUL' : '/dev/null'

    stdin = File.open(arguments[:stdinfile] || null_file, 'r')
    stdout = arguments[:squelch] ? File.open(null_file, 'w') : Tempfile.new('puppet')
    stderr = arguments[:combine] ? stdout : File.open(null_file, 'w')


    exec_args = [command, arguments, stdin, stdout, stderr]

    if execution_stub = Puppet::Util::ExecutionStub.current_value
      return execution_stub.call(*exec_args)
    elsif Puppet.features.posix?
      child_pid = execute_posix(*exec_args)
      child_status = Process.waitpid2(child_pid).last.exitstatus
    elsif Puppet.features.microsoft_windows?
      child_pid = execute_windows(*exec_args)
      child_status = Process.waitpid2(child_pid).last
    end

    [stdin, stdout, stderr].each {|io| io.close rescue nil}

    # read output in if required
    unless arguments[:squelch]
      output = wait_for_output(stdout)
      Puppet.warning "Could not get output" unless output
    end

    if arguments[:failonfail] and child_status != 0
      raise ExecutionFailure, "Execution of '#{str}' returned #{child_status}: #{output}"
    end

    output
  end

  module_function :execute

  def wait_for_output(stdout)
    # Make sure the file's actually been written.  This is basically a race
    # condition, and is probably a horrible way to handle it, but, well, oh
    # well.
    2.times do |try|
      if File.exists?(stdout.path)
        output = stdout.open.read

        stdout.close(true)

        return output
      else
        time_to_sleep = try / 2.0
        Puppet.warning "Waiting for output; will sleep #{time_to_sleep} seconds"
        sleep(time_to_sleep)
      end
    end
    nil
  end
  module_function :wait_for_output

  # Create an exclusive lock.
  def threadlock(resource, type = Sync::EX)
    Puppet::Util.synchronize_on(resource,type) { yield }
  end

  # Because some modules provide their own version of this method.
  alias util_execute execute

  module_function :benchmark

  def memory
    unless defined?(@pmap)
      @pmap = which('pmap')
    end
    if @pmap
      %x{#{@pmap} #{Process.pid}| grep total}.chomp.sub(/^\s*total\s+/, '').sub(/K$/, '').to_i
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

    hash
  end
  module_function :symbolize, :symbolizehash, :symbolizehash!

  # Just benchmark, with no logging.
  def thinmark
    seconds = Benchmark.realtime {
      yield
    }

    seconds
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
