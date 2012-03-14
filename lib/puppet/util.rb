# A module to collect utility functions.

require 'English'
require 'puppet/util/monkey_patches'
require 'puppet/external/lock'
require 'puppet/error'
require 'puppet/util/execution_stub'
require 'uri'
require 'sync'
require 'monitor'
require 'tempfile'
require 'pathname'

module Puppet

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
        begin
          dest = File.expand_path(File.join(dir, bin))
        rescue ArgumentError => e
          # if the user's PATH contains a literal tilde (~) character and HOME is not set, we may get
          # an ArgumentError here.  Let's check to see if that is the case; if not, re-raise whatever error
          # was thrown.
          raise e unless ((dir =~ /~/) && ((ENV['HOME'].nil? || ENV['HOME'] == "")))

          # if we get here they have a tilde in their PATH.  We'll issue a single warning about this and then
          # ignore this path element and carry on with our lives.
          Puppet::Util::Warnings.warnonce("PATH contains a ~ character, and HOME is not set; ignoring PATH element '#{dir}'.")
          next
        end
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

  # Create an exclusive lock.
  def threadlock(resource, type = Sync::EX)
    Puppet::Util.synchronize_on(resource,type) { yield }
  end


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

  # Because IO#binread is only available in 1.9
  def binread(file)
    File.open(file, 'rb') { |f| f.read }
  end
  module_function :binread

  # utility method to get the current call stack and format it to a human-readable string (which some IDEs/editors
  # will recognize as links to the line numbers in the trace)
  def self.pretty_backtrace(backtrace = caller(1))
    backtrace.collect do |line|
      file_path, line_num = line.split(":")
      file_path = expand_symlinks(File.expand_path(file_path))

      file_path + ":" + line_num
    end .join("\n")

  end

  # utility method that takes a path as input, checks each component of the path to see if it is a symlink, and expands
  # it if it is.  returns the expanded path.
  def self.expand_symlinks(file_path)
    file_path.split("/").inject do |full_path, next_dir|
      next_path = full_path + "/" + next_dir
      if File.symlink?(next_path) then
        link = File.readlink(next_path)
        next_path =
            case link
              when /^\// then link
              else
                File.expand_path(full_path + "/" + link)
            end
      end
      next_path
    end
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


  #TODO cprice: document
  def exit_on_fail(message, code = 1)
    yield
  rescue ArgumentError, RuntimeError, NotImplementedError => detail
    Puppet.log_exception(detail, "Could not #{message}: #{detail}")
    exit(code)
  end
  module_function :exit_on_fail


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

  def execute(command, arguments = {})
    Puppet.deprecation_warning("Puppet::Util.execute is deprecated; please use Puppet::Util::Execution.execute")
    Puppet::Util::Execution.execute(command, arguments)
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
