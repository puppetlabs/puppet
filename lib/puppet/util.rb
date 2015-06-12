# A module to collect utility functions.

require 'English'
require 'puppet/error'
require 'puppet/util/execution_stub'
require 'uri'
require 'pathname'
require 'ostruct'
require 'puppet/util/platform'
require 'puppet/util/symbolic_file_mode'
require 'puppet/file_system/uniquefile'
require 'securerandom'

module Puppet
module Util
  require 'puppet/util/monkey_patches'
  require 'benchmark'

  # These are all for backward compatibility -- these are methods that used
  # to be in Puppet::Util but have been moved into external modules.
  require 'puppet/util/posix'
  extend Puppet::Util::POSIX

  extend Puppet::Util::SymbolicFileMode

  def self.activerecord_version
    if (defined?(::ActiveRecord) and defined?(::ActiveRecord::VERSION) and defined?(::ActiveRecord::VERSION::MAJOR) and defined?(::ActiveRecord::VERSION::MINOR))
      ([::ActiveRecord::VERSION::MAJOR, ::ActiveRecord::VERSION::MINOR].join('.').to_f)
    else
      0
    end
  end


  # Run some code with a specific environment.  Resets the environment back to
  # what it was at the end of the code.
  def self.withenv(hash)
    saved = ENV.to_hash
    hash.each do |name, val|
      ENV[name.to_s] = val
    end

    yield
  ensure
    ENV.clear
    saved.each do |name, val|
      ENV[name] = val
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
      seconds = Benchmark.realtime {
        yield
      }
      object.send(level, msg + (" in %0.2f seconds" % seconds))
      return seconds
    else
      yield
    end
  end
  module_function :benchmark

  # Resolve a path for an executable to the absolute path. This tries to behave
  # in the same manner as the unix `which` command and uses the `PATH`
  # environment variable.
  #
  # @api public
  # @param bin [String] the name of the executable to find.
  # @return [String] the absolute path to the found executable.
  def which(bin)
    if absolute_path?(bin)
      return bin if FileTest.file? bin and FileTest.executable? bin
    else
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
        begin
          dest = File.expand_path(File.join(dir, bin))
        rescue ArgumentError => e
          # if the user's PATH contains a literal tilde (~) character and HOME is not set, we may get
          # an ArgumentError here.  Let's check to see if that is the case; if not, re-raise whatever error
          # was thrown.
          if e.to_s =~ /HOME/ and (ENV['HOME'].nil? || ENV['HOME'] == "")
            # if we get here they have a tilde in their PATH.  We'll issue a single warning about this and then
            # ignore this path element and carry on with our lives.
            Puppet::Util::Warnings.warnonce("PATH contains a ~ character, and HOME is not set; ignoring PATH element '#{dir}'.")
          elsif e.to_s =~ /doesn't exist|can't find user/
            # ...otherwise, we just skip the non-existent entry, and do nothing.
            Puppet::Util::Warnings.warnonce("Couldn't expand PATH containing a ~ character; ignoring PATH element '#{dir}'.")
          else
            raise
          end
        else
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
    end
    nil
  end
  module_function :which

  # Determine in a platform-specific way whether a path is absolute. This
  # defaults to the local platform if none is specified.
  #
  # Escape once for the string literal, and once for the regex.
  slash = '[\\\\/]'
  label = '[^\\\\/]+'
  AbsolutePathWindows = %r!^(?:(?:[A-Z]:#{slash})|(?:#{slash}#{slash}#{label}#{slash}#{label})|(?:#{slash}#{slash}\?#{slash}#{label}))!io
  AbsolutePathPosix   = %r!^/!
  def absolute_path?(path, platform=nil)
    # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
    # library uses that to test what platform it's on.  Normally in Puppet we
    # would use Puppet.features.microsoft_windows?, but this method needs to
    # be called during the initialization of features so it can't depend on
    # that.
    platform ||= Puppet::Util::Platform.windows? ? :windows : :posix
    regex = case platform
            when :windows
              AbsolutePathWindows
            when :posix
              AbsolutePathPosix
            else
              raise Puppet::DevError, "unknown platform #{platform} in absolute_path"
            end

    !! (path =~ regex)
  end
  module_function :absolute_path?

  # Convert a path to a file URI
  def path_to_uri(path)
    return unless path

    params = { :scheme => 'file' }

    if Puppet.features.microsoft_windows?
      path = path.gsub(/\\/, '/')

      if unc = /^\/\/([^\/]+)(\/.+)/.match(path)
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
      raise Puppet::Error, "Failed to convert '#{path}' to URI: #{detail}", detail.backtrace
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

  def safe_posix_fork(stdin=$stdin, stdout=$stdout, stderr=$stderr, &block)
    child_pid = Kernel.fork do
      $stdin.reopen(stdin)
      $stdout.reopen(stdout)
      $stderr.reopen(stderr)

      begin
        Dir.foreach('/proc/self/fd') do |f|
          if f != '.' && f != '..' && f.to_i >= 3
            IO::new(f.to_i).close rescue nil
          end
        end
      rescue Errno::ENOENT # /proc/self/fd not found
        3.upto(256){|fd| IO::new(fd).close rescue nil}
      end

      block.call if block
    end
    child_pid
  end
  module_function :safe_posix_fork

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

  def symbolizehash(hash)
    newhash = {}
    hash.each do |name, val|
      name = name.intern if name.respond_to? :intern
      newhash[name] = val
    end
    newhash
  end
  module_function :symbolizehash

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
    Puppet.deprecation_warning("Puppet::Util.binread is deprecated. Read the file without this method as it will be removed in a future version.")
    File.open(file, 'rb') { |f| f.read }
  end
  module_function :binread

  # utility method to get the current call stack and format it to a human-readable string (which some IDEs/editors
  # will recognize as links to the line numbers in the trace)
  def self.pretty_backtrace(backtrace = caller(1))
    backtrace.collect do |line|
      _, path, rest = /^(.*):(\d+.*)$/.match(line).to_a
      # If the path doesn't exist - like in one test, and like could happen in
      # the world - we should just tolerate it and carry on. --daniel 2012-09-05
      # Also, if we don't match, just include the whole line.
      if path
        path = Pathname(path).realpath rescue path
        "#{path}:#{rest}"
      else
        line
      end
    end.join("\n")
  end

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
  # across. The default_mode can be expressed as an octal integer, a numeric string (ie '0664')
  # or a symbolic file mode.

  DEFAULT_POSIX_MODE = 0644
  DEFAULT_WINDOWS_MODE = nil

  def replace_file(file, default_mode, &block)
    raise Puppet::DevError, "replace_file requires a block" unless block_given?

    if default_mode
      unless valid_symbolic_mode?(default_mode)
        raise Puppet::DevError, "replace_file default_mode: #{default_mode} is invalid"
      end

      mode = symbolic_mode_to_int(normalize_symbolic_mode(default_mode))
    else
      if Puppet.features.microsoft_windows?
        mode = DEFAULT_WINDOWS_MODE
      else
        mode = DEFAULT_POSIX_MODE
      end
    end

    begin
      file     = Puppet::FileSystem.pathname(file)
      tempfile = Puppet::FileSystem::Uniquefile.new(Puppet::FileSystem.basename_string(file), Puppet::FileSystem.dir_string(file))

      # Set properties of the temporary file before we write the content, because
      # Tempfile doesn't promise to be safe from reading by other people, just
      # that it avoids races around creating the file.
      #
      # Our Windows emulation is pretty limited, and so we have to carefully
      # and specifically handle the platform, which has all sorts of magic.
      # So, unlike Unix, we don't pre-prep security; we use the default "quite
      # secure" tempfile permissions instead.  Magic happens later.
      if !Puppet.features.microsoft_windows?
        # Grab the current file mode, and fall back to the defaults.
        effective_mode =
        if Puppet::FileSystem.exist?(file)
          stat = Puppet::FileSystem.lstat(file)
          tempfile.chown(stat.uid, stat.gid)
          stat.mode
        else
          mode
        end

        if effective_mode
          # We only care about the bottom four slots, which make the real mode,
          # and not the rest of the platform stat call fluff and stuff.
          tempfile.chmod(effective_mode & 07777)
        end
      end

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

      if Puppet.features.microsoft_windows?
        # Windows ReplaceFile needs a file to exist, so touch handles this
        if !Puppet::FileSystem.exist?(file)
          Puppet::FileSystem.touch(file)
          if mode
            Puppet::Util::Windows::Security.set_mode(mode, Puppet::FileSystem.path_string(file))
          end
        end
        # Yes, the arguments are reversed compared to the rename in the rest
        # of the world.
        Puppet::Util::Windows::File.replace_file(FileSystem.path_string(file), tempfile.path)

      else
        File.rename(tempfile.path, Puppet::FileSystem.path_string(file))
      end
    ensure
      # in case an error occurred before we renamed the temp file, make sure it
      # gets deleted
      if tempfile
        tempfile.close!
      end
    end


    # Ideally, we would now fsync the directory as well, but Ruby doesn't
    # have support for that, and it doesn't matter /that/ much...

    # Return something true, and possibly useful.
    file
  end
  module_function :replace_file

  # Executes a block of code, wrapped with some special exception handling.  Causes the ruby interpreter to
  #  exit if the block throws an exception.
  #
  # @api public
  # @param [String] message a message to log if the block fails
  # @param [Integer] code the exit code that the ruby interpreter should return if the block fails
  # @yield
  def exit_on_fail(message, code = 1)
    yield
  # First, we need to check and see if we are catching a SystemExit error.  These will be raised
  #  when we daemonize/fork, and they do not necessarily indicate a failure case.
  rescue SystemExit => err
    raise err

  # Now we need to catch *any* other kind of exception, because we may be calling third-party
  #  code (e.g. webrick), and we have no idea what they might throw.
  rescue Exception => err
    ## NOTE: when debugging spec failures, these two lines can be very useful
    #puts err.inspect
    #puts Puppet::Util.pretty_backtrace(err.backtrace)
    Puppet.log_exception(err, "Could not #{message}: #{err}")
    Puppet::Util::Log.force_flushqueue()
    exit(code)
  end
  module_function :exit_on_fail

  def deterministic_rand(seed,max)
    if defined?(Random) == 'constant' && Random.class == Class
      Random.new(seed).rand(max).to_s
    else
      srand(seed)
      result = rand(max).to_s
      srand()
      result
    end
  end
  module_function :deterministic_rand


  #######################################################################################################
  # Deprecated methods relating to process execution; these have been moved to Puppet::Util::Execution
  #######################################################################################################

  def execpipe(command, failonfail = true, &block)
    Puppet.deprecation_warning("Puppet::Util.execpipe is deprecated; please use Puppet::Util::Execution.execpipe")
    Puppet::Util::Execution.execpipe(command, failonfail, &block)
  end
  module_function :execpipe

  def execfail(command, exception)
    Puppet.deprecation_warning("Puppet::Util.execfail is deprecated; please use Puppet::Util::Execution.execfail")
    Puppet::Util::Execution.execfail(command, exception)
  end
  module_function :execfail

  def execute(*args)
    Puppet.deprecation_warning("Puppet::Util.execute is deprecated; please use Puppet::Util::Execution.execute")

    Puppet::Util::Execution.execute(*args)
  end
  module_function :execute

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
