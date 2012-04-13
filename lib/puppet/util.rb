# A module to collect utility functions.

require 'English'
require 'puppet/util/monkey_patches'
require 'puppet/external/lock'
require 'puppet/util/execution_stub'
require 'uri'
require 'sync'
require 'monitor'
require 'tempfile'
require 'pathname'

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
        dest = File.expand_path(File.join(dir, bin))
        if Puppet.features.microsoft_windows? && File.extname(dest).empty?
          exts = ENV['PATHEXT']
          exts = exts ? exts.split(File::PATH_SEPARATOR) : %w[.COM .EXE .BAT .CMD]
          exts.each do |ext|
            destext = File.expand_path(dest + ext)
            return destext if FileTest.file? destext and FileTest.executable? destext
          end
        end
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

    # Due to weird load order issues, I was unable to remove this require.
    # This is fixed in Telly so it can be removed there.
    require 'puppet'

    # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
    # library uses that to test what platform it's on.  Normally in Puppet we
    # would use Puppet.features.microsoft_windows?, but this method needs to
    # be called during the initialization of features so it can't depend on
    # that.
    platform ||= File::ALT_SEPARATOR ? :windows : :posix

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

  # Execute the provided command with STDIN connected to a pipe, yielding the
  # pipe object.  That allows data to be fed to that subprocess.
  #
  # The command can be a simple string, which is executed as-is, or an Array,
  # which is treated as a set of command arguments to pass through.#
  #
  # In all cases this is passed directly to the shell, and STDOUT and STDERR
  # are connected together during execution.
  def execpipe(command, failonfail = true)
    if respond_to? :debug
      debug "Executing '#{command}'"
    else
      Puppet.debug "Executing '#{command}'"
    end

    # Paste together an array with spaces.  We used to paste directly
    # together, no spaces, which made for odd invocations; the user had to
    # include whitespace between arguments.
    #
    # Having two spaces is really not a big drama, since this passes to the
    # shell anyhow, while no spaces makes for a small developer cost every
    # time this is invoked. --daniel 2012-02-13
    command_str = command.respond_to?(:join) ? command.join(' ') : command
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
    child_pid = safe_posix_fork(stdin, stdout, stderr) do
      # We can't just call Array(command), and rely on it returning
      # things like ['foo'], when passed ['foo'], because
      # Array(command) will call command.to_a internally, which when
      # given a string can end up doing Very Bad Things(TM), such as
      # turning "/tmp/foo;\r\n /bin/echo" into ["/tmp/foo;\r\n", " /bin/echo"]
      command = [command].flatten
      Process.setsid
      begin
        Puppet::Util::SUIDManager.change_privileges(arguments[:uid], arguments[:gid], true)

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

  def safe_posix_fork(stdin=$stdin, stdout=$stdout, stderr=$stderr, &block)
    child_pid = Kernel.fork do
      $stdin.reopen(stdin)
      $stdout.reopen(stdout)
      $stderr.reopen(stderr)

      3.upto(256){|fd| IO::new(fd).close rescue nil}

      block.call if block
    end
    child_pid
  end
  module_function :safe_posix_fork

  def execute_windows(command, arguments, stdin, stdout, stderr)
    command = command.map do |part|
      part.include?(' ') ? %Q["#{part.gsub(/"/, '\"')}"] : part
    end.join(" ") if command.is_a?(Array)

    Puppet::Util::Windows::Process.execute(command, arguments, stdin, stdout, stderr)
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
      exit_status = Process.waitpid2(child_pid).last.exitstatus
    elsif Puppet.features.microsoft_windows?
      process_info = execute_windows(*exec_args)
      begin
        exit_status = Puppet::Util::Windows::Process.wait_process(process_info.process_handle)
      ensure
        Process.CloseHandle(process_info.process_handle)
        Process.CloseHandle(process_info.thread_handle)
      end
    end

    [stdin, stdout, stderr].each {|io| io.close rescue nil}

    # read output in if required
    unless arguments[:squelch]
      output = wait_for_output(stdout)
      Puppet.warning "Could not get output" unless output
    end

    if arguments[:failonfail] and exit_status != 0
      raise ExecutionFailure, "Execution of '#{str}' returned #{exit_status}: #{output}"
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
    newhash
  end

  def symbolizehash!(hash)
    # this is not the most memory-friendly way to accomplish this, but the
    #  code re-use and clarity seems worthwhile.
    newhash = symbolizehash(hash)
    hash.clear
    hash.merge!(newhash)

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

  # Because IO#binread is only available in 1.9
  def binread(file)
    File.open(file, 'rb') { |f| f.read }
  end
  module_function :binread

  # Replace a file, securely.  This takes a block, and passes it the file
  # handle of a file open for writing.  Write the replacement content inside
  # the block and it will safely replace the target file.
  #
  # This method will make no changes to the target file until the content is
  # successfully written and the block returns without raising an error.
  #
  # As far as possible the state of the existing file, such as mode, is
  # preserved.  This works hard to avoid loss of any metadata, but will result
  # in an inode change for the file.
  #
  # Arguments: `filename`, `default_mode`
  #
  # The filename is the file we are going to replace.
  #
  # The default_mode is the mode to use when the target file doesn't already
  # exist; if the file is present we copy the existing mode/owner/group values
  # across.
  def replace_file(file, default_mode, &block)
    raise Puppet::DevError, "replace_file requires a block" unless block_given?
    raise Puppet::DevError, "replace_file is non-functional on Windows" if Puppet.features.microsoft_windows?

    file     = Pathname(file)
    tempfile = Tempfile.new(file.basename.to_s, file.dirname.to_s)

    file_exists = file.exist?

    # If the file exists, use its current mode/owner/group. If it doesn't, use
    # the supplied mode, and default to current user/group.
    if file_exists
      stat = file.lstat

      # We only care about the four lowest-order octets. Higher octets are
      # filesystem-specific.
      mode = stat.mode & 07777
      uid = stat.uid
      gid = stat.gid
    else
      mode = default_mode
      uid = Process.euid
      gid = Process.egid
    end

    # Set properties of the temporary file before we write the content, because
    # Tempfile doesn't promise to be safe from reading by other people, just
    # that it avoids races around creating the file.
    tempfile.chmod(mode)
    tempfile.chown(uid, gid)

    # OK, now allow the caller to write the content of the file.
    yield tempfile

    # Now, make sure the data (which includes the mode) is safe on disk.
    tempfile.flush
    begin
      tempfile.fsync
    rescue NotImplementedError
      # fsync may not be implemented by Ruby on all platforms, but
      # there is absolutely no recovery path if we detect that.  So, we just
      # ignore the return code.
      #
      # However, don't be fooled: that is accepting that we are running in
      # an unsafe fashion.  If you are porting to a new platform don't stub
      # that out.
    end

    tempfile.close

    File.rename(tempfile.path, file)

    # Ideally, we would now fsync the directory as well, but Ruby doesn't
    # have support for that, and it doesn't matter /that/ much...

    # Return something true, and possibly useful.
    file
  end
  module_function :replace_file
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
