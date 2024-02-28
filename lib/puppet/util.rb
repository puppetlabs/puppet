# frozen_string_literal: true

# A module to collect utility functions.

require 'English'
require_relative '../puppet/error'
require_relative 'util/execution_stub'
require 'uri'
require 'pathname'
require 'ostruct'
require_relative 'util/platform'
require_relative 'util/windows'
require_relative 'util/symbolic_file_mode'
require_relative '../puppet/file_system/uniquefile'
require 'securerandom'
require_relative 'util/character_encoding'

module Puppet
module Util
  require_relative 'util/monkey_patches'
  require 'benchmark'

  # These are all for backward compatibility -- these are methods that used
  # to be in Puppet::Util but have been moved into external modules.
  require_relative 'util/posix'
  extend Puppet::Util::POSIX

  require_relative 'util/windows/process' if Puppet::Util::Platform.windows?

  extend Puppet::Util::SymbolicFileMode

  def default_env
    Puppet.features.microsoft_windows? ?
      :windows :
      :posix
  end
  module_function :default_env

  def create_erb(content)
    ERB.new(content, trim_mode: '-')
  end
  module_function :create_erb

  # @deprecated Use ENV instead
  # @api private
  def get_env(name, mode = default_env)
    ENV.fetch(name, nil)
  end
  module_function :get_env

  # @deprecated Use ENV instead
  # @api private
  def get_environment(mode = default_env)
    ENV.to_hash
  end
  module_function :get_environment

  # @deprecated Use ENV instead
  # @api private
  def clear_environment(mode = default_env)
    ENV.clear
  end
  module_function :clear_environment

  # @deprecated Use ENV instead
  # @api private
  def set_env(name, value = nil, mode = default_env)
    ENV[name] = value
  end
  module_function :set_env

  # @deprecated Use ENV instead
  # @api private
  def merge_environment(env_hash, mode = default_env)
    ENV.merge!(hash.transform_keys(&:to_s))
  end
  module_function :merge_environment

  # Run some code with a specific environment.  Resets the environment back to
  # what it was at the end of the code.
  #
  # @param hash [Hash{String,Symbol => String}] Environment variables to override the current environment.
  # @param mode [Symbol] ignored
  def withenv(hash, mode = :posix)
    saved = ENV.to_hash
    begin
      ENV.merge!(hash.transform_keys(&:to_s))
      yield
    ensure
      ENV.replace(saved)
    end
  end
  module_function :withenv

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
    group = Puppet[:group]
    if group
      begin
        Puppet::Util::SUIDManager.change_group(group, true)
      rescue => detail
        Puppet.warning _("could not change to group %{group}: %{detail}") % { group: group.inspect, detail: detail }
        $stderr.puts _("could not change to group %{group}") % { group: group.inspect }

        # Don't exit on failed group changes, since it's
        # not fatal
        # exit(74)
      end
    end

    user = Puppet[:user]
    if user
      begin
        Puppet::Util::SUIDManager.change_user(user, true)
      rescue => detail
        $stderr.puts _("Could not change to user %{user}: %{detail}") % { user: user, detail: detail }
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

  # execute a block of work and based on the logging level provided, log the provided message with the seconds taken
  # The message 'msg' should include string ' in %{seconds} seconds' as part of the message and any content should escape
  # any percent signs '%' so that they are not interpreted as formatting commands
  #     escaped_str = str.gsub(/%/, '%%')
  #
  # @param msg [String] the message to be formated to assigned the %{seconds} seconds take to execute,
  #                     other percent signs '%' need to be escaped
  # @param level [Symbol] the logging level for this message
  # @param object [Object] The object use for logging the message
  def benchmark(*args)
    msg = args.pop
    level = args.pop
    object = if args.empty?
               if respond_to?(level)
                 self
               else
                 Puppet
               end
             else
               args.pop
             end

    # TRANSLATORS 'benchmark' is a method name and should not be translated
    raise Puppet::DevError, _("Failed to provide level to benchmark") unless level

    unless level == :none or object.respond_to? level
      raise Puppet::DevError, _("Benchmarked object does not respond to %{value}") % { value: level }
    end

    # Only benchmark if our log level is high enough
    if level != :none and Puppet::Util::Log.sendlevel?(level)
      seconds = Benchmark.realtime {
        yield
      }
      object.send(level, msg % { seconds: "%0.2f" % seconds })
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
      exts = ENV.fetch('PATHEXT', nil)
      exts = exts ? exts.split(File::PATH_SEPARATOR) : %w[.COM .EXE .BAT .CMD]
      ENV.fetch('PATH').split(File::PATH_SEPARATOR).each do |dir|
        begin
          dest = File.expand_path(File.join(dir, bin))
        rescue ArgumentError => e
          # if the user's PATH contains a literal tilde (~) character and HOME is not set, we may get
          # an ArgumentError here.  Let's check to see if that is the case; if not, re-raise whatever error
          # was thrown.
          if e.to_s =~ /HOME/ and (ENV['HOME'].nil? || ENV.fetch('HOME', nil) == "")
            # if we get here they have a tilde in their PATH.  We'll issue a single warning about this and then
            # ignore this path element and carry on with our lives.
            # TRANSLATORS PATH and HOME are environment variables and should not be translated
            Puppet::Util::Warnings.warnonce(_("PATH contains a ~ character, and HOME is not set; ignoring PATH element '%{dir}'.") % { dir: dir })
          elsif e.to_s =~ /doesn't exist|can't find user/
            # ...otherwise, we just skip the non-existent entry, and do nothing.
            # TRANSLATORS PATH is an environment variable and should not be translated
            Puppet::Util::Warnings.warnonce(_("Couldn't expand PATH containing a ~ character; ignoring PATH element '%{dir}'.") % { dir: dir })
          else
            raise
          end
        else
          if Puppet::Util::Platform.windows? && File.extname(dest).empty?
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
  AbsolutePathWindows = %r{^(?:(?:[A-Z]:#{slash})|(?:#{slash}#{slash}#{label}#{slash}#{label})|(?:#{slash}#{slash}\?#{slash}#{label}))}io
  AbsolutePathPosix   = %r{^/}
  def absolute_path?(path, platform = nil)
    unless path.is_a?(String)
      Puppet.warning("Cannot check if #{path} is an absolute path because it is a '#{path.class}' and not a String'")
      return false
    end

    # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
    # library uses that to test what platform it's on.  Normally in Puppet we
    # would use Puppet.features.microsoft_windows?, but this method needs to
    # be called during the initialization of features so it can't depend on
    # that.
    #
    # @deprecated Use ruby's built-in methods to determine if a path is absolute.
    platform ||= Puppet::Util::Platform.windows? ? :windows : :posix
    regex = case platform
            when :windows
              AbsolutePathWindows
            when :posix
              AbsolutePathPosix
            else
              raise Puppet::DevError, _("unknown platform %{platform} in absolute_path") % { platform: platform }
            end

    !!(path =~ regex)
  end
  module_function :absolute_path?

  # Convert a path to a file URI
  def path_to_uri(path)
    return unless path

    params = { :scheme => 'file' }

    if Puppet::Util::Platform.windows?
      path = path.tr('\\', '/')

      unc = /^\/\/([^\/]+)(\/.+)/.match(path)
      if unc
        params[:host] = unc[1]
        path = unc[2]
      elsif path =~ /^[a-z]:\//i
        path = '/' + path
      end
    end

    # have to split *after* any relevant escaping
    params[:path], params[:query] = uri_encode(path).split('?')
    search_for_fragment = params[:query] ? :query : :path
    if params[search_for_fragment].include?('#')
      params[search_for_fragment], _, params[:fragment] = params[search_for_fragment].rpartition('#')
    end

    begin
      URI::Generic.build(params)
    rescue => detail
      raise Puppet::Error, _("Failed to convert '%{path}' to URI: %{detail}") % { path: path, detail: detail }, detail.backtrace
    end
  end
  module_function :path_to_uri

  # Get the path component of a URI
  def uri_to_path(uri)
    return unless uri.is_a?(URI)

    # CGI.unescape doesn't handle space rules properly in uri paths
    # URI.unescape does, but returns strings in their original encoding
    path = uri_unescape(uri.path.encode(Encoding::UTF_8))

    if Puppet::Util::Platform.windows? && uri.scheme == 'file'
      if uri.host && !uri.host.empty?
        path = "//#{uri.host}" + path # UNC
      else
        path.sub!(/^\//, '')
      end
    end

    path
  end
  module_function :uri_to_path

  RFC_3986_URI_REGEX = /^(?<scheme>(?:[^:\/?#]+):)?(?<authority>\/\/(?:[^\/?#]*))?(?<path>[^?#]*)(?:\?(?<query>[^#]*))?(?:#(?<fragment>.*))?$/

  # Percent-encodes a URI query parameter per RFC3986 - https://tools.ietf.org/html/rfc3986
  #
  # The output will correctly round-trip through URI.unescape
  #
  # @param [String query_string] A URI query parameter that may contain reserved
  #   characters that must be percent encoded for the key or value to be
  #   properly decoded as part of a larger query string:
  #
  #   query
  #   encodes as : query
  #
  #   query_with_special=chars like&and * and# plus+this
  #   encodes as:
  #   query_with_special%3Dchars%20like%26and%20%2A%20and%23%20plus%2Bthis
  #
  #   Note: Also usable by fragments, but not suitable for paths
  #
  # @return [String] a new string containing an encoded query string per the
  #   rules of RFC3986.
  #
  #   In particular,
  #   query will encode + as %2B and space as %20
  def uri_query_encode(query_string)
    return nil if query_string.nil?

    # query can encode space to %20 OR +
    # + MUST be encoded as %2B
    # in RFC3968 both query and fragment are defined as:
    # = *( pchar / "/" / "?" )
    # CGI.escape turns space into + which is the most backward compatible
    # however it doesn't roundtrip through URI.unescape which prefers %20
    CGI.escape(query_string).gsub('+', '%20')
  end
  module_function :uri_query_encode

  # Percent-encodes a URI string per RFC3986 - https://tools.ietf.org/html/rfc3986
  #
  # Properly handles escaping rules for paths, query strings and fragments
  # independently
  #
  # The output is safe to pass to URI.parse or URI::Generic.build and will
  # correctly round-trip through URI.unescape
  #
  # @param [String path] A URI string that may be in the form of:
  #
  #   http://foo.com/bar?query
  #   file://tmp/foo bar
  #   //foo.com/bar?query
  #   /bar?query
  #   bar?query
  #   bar
  #   .
  #   C:\Windows\Temp
  #
  #   Note that with no specified scheme, authority or query parameter delimiter
  #   ? that a naked string will be treated as a path.
  #
  #   Note that if query parameters need to contain data such as & or =
  #   that this method should not be used, as there is no way to differentiate
  #   query parameter data from query delimiters when multiple parameters
  #   are specified
  #
  # @param [Hash{Symbol=>String} opts] Options to alter encoding
  # @option opts [Array<Symbol>] :allow_fragment defaults to false. When false
  #   will treat # as part of a path or query and not a fragment delimiter
  #
  # @return [String] a new string containing appropriate portions of the URI
  #   encoded per the rules of RFC3986.
  #   In particular,
  #   path will not encode +, but will encode space as %20
  #   query will encode + as %2B and space as %20
  #   fragment behaves like query
  def uri_encode(path, opts = { :allow_fragment => false })
    raise ArgumentError, _('path may not be nil') if path.nil?

    encoded = ''.dup

    # parse uri into named matches, then reassemble properly encoded
    parts = path.match(RFC_3986_URI_REGEX)

    encoded += parts[:scheme] unless parts[:scheme].nil?
    encoded += parts[:authority] unless parts[:authority].nil?

    # path requires space to be encoded as %20 (NEVER +)
    # + should be left unencoded
    # URI::parse and URI::Generic.build don't like paths encoded with CGI.escape
    # URI.escape does not change / to %2F and : to %3A like CGI.escape
    #
    encoded += rfc2396_escape(parts[:path]) unless parts[:path].nil?

    # each query parameter
    unless parts[:query].nil?
      query_string = parts[:query].split('&').map do |pair|
        # can optionally be separated by an =
        pair.split('=').map do |v|
          uri_query_encode(v)
        end.join('=')
      end.join('&')
      encoded += '?' + query_string
    end

    encoded += ((opts[:allow_fragment] ? '#' : '%23') + uri_query_encode(parts[:fragment])) unless parts[:fragment].nil?

    encoded
  end
  module_function :uri_encode

  # From https://github.com/ruby/ruby/blob/v2_7_3/lib/uri/rfc2396_parser.rb#L24-L46
  ALPHA = "a-zA-Z"
  ALNUM = "#{ALPHA}\\d"
  UNRESERVED = "\\-_.!~*'()#{ALNUM}"
  RESERVED = ";/?:@&=+$,\\[\\]"
  UNSAFE = Regexp.new("[^#{UNRESERVED}#{RESERVED}]").freeze

  HEX = "a-fA-F\\d"
  ESCAPED = Regexp.new("%[#{HEX}]{2}").freeze

  def rfc2396_escape(str)
    str.gsub(UNSAFE) do |match|
      tmp = ''.dup
      match.each_byte do |uc|
        tmp << sprintf('%%%02X', uc)
      end
      tmp
    end.force_encoding(Encoding::US_ASCII)
  end
  module_function :rfc2396_escape

  def uri_unescape(str)
    enc = str.encoding
    enc = Encoding::UTF_8 if enc == Encoding::US_ASCII
    str.gsub(ESCAPED) { [::Regexp.last_match(0)[1, 2]].pack('H2').force_encoding(enc) }
  end
  module_function :uri_unescape

  def safe_posix_fork(stdin = $stdin, stdout = $stdout, stderr = $stderr, &block)
    Kernel.fork do
      STDIN.reopen(stdin)
      STDOUT.reopen(stdout)
      STDERR.reopen(stderr)

      $stdin = STDIN
      $stdout = STDOUT
      $stderr = STDERR

      begin
        Dir.foreach('/proc/self/fd') do |f|
          if f != '.' && f != '..' && f.to_i >= 3
            IO.new(f.to_i).close rescue nil
          end
        end
      rescue Errno::ENOENT, Errno::ENOTDIR # /proc/self/fd not found, /proc/self not a dir
        3.upto(256) { |fd| IO.new(fd).close rescue nil }
      end

      block.call if block
    end
  end
  module_function :safe_posix_fork

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
    Benchmark.realtime {
      yield
    }
  end

  module_function :thinmark

  PUPPET_STACK_INSERTION_FRAME = /.*puppet_stack\.rb.*in.*`stack'/

  # utility method to get the current call stack and format it to a human-readable string (which some IDEs/editors
  # will recognize as links to the line numbers in the trace)
  def self.pretty_backtrace(backtrace = caller(1), puppetstack = [])
    format_backtrace_array(backtrace, puppetstack).join("\n")
  end

  # arguments may be a Ruby stack, with an optional Puppet stack argument,
  # or just a Puppet stack.
  # stacks may be an Array of Strings "/foo.rb:0 in `blah'" or
  # an Array of Arrays that represent a frame: ["/foo.pp", 0]
  def self.format_backtrace_array(primary_stack, puppetstack = [])
    primary_stack.flat_map do |frame|
      frame = format_puppetstack_frame(frame) if frame.is_a?(Array)
      primary_frame = resolve_stackframe(frame)

      if primary_frame =~ PUPPET_STACK_INSERTION_FRAME && !puppetstack.empty?
        [resolve_stackframe(format_puppetstack_frame(puppetstack.shift)),
         primary_frame]
      else
        primary_frame
      end
    end
  end

  def self.resolve_stackframe(frame)
    _, path, rest = /^(.*):(\d+.*)$/.match(frame).to_a
    if path
      path = Pathname(path).realpath rescue path
      "#{path}:#{rest}"
    else
      frame
    end
  end

  def self.format_puppetstack_frame(file_and_lineno)
    file_and_lineno.join(':')
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
  # Arguments: `filename`, `default_mode`, `staging_location`
  #
  # The filename is the file we are going to replace.
  #
  # The default_mode is the mode to use when the target file doesn't already
  # exist; if the file is present we copy the existing mode/owner/group values
  # across. The default_mode can be expressed as an octal integer, a numeric string (ie '0664')
  # or a symbolic file mode.
  #
  # The staging_location is a location to render the temporary file before
  # moving the file to it's final location.

  DEFAULT_POSIX_MODE = 0o644
  DEFAULT_WINDOWS_MODE = nil

  def replace_file(file, default_mode, staging_location: nil, validate_callback: nil, &block)
    raise Puppet::DevError, _("replace_file requires a block") unless block_given?

    if default_mode
      unless valid_symbolic_mode?(default_mode)
        raise Puppet::DevError, _("replace_file default_mode: %{default_mode} is invalid") % { default_mode: default_mode }
      end

      mode = symbolic_mode_to_int(normalize_symbolic_mode(default_mode))
    elsif Puppet::Util::Platform.windows?
      mode = DEFAULT_WINDOWS_MODE
    else
      mode = DEFAULT_POSIX_MODE
    end

    begin
      file = Puppet::FileSystem.pathname(file)

      # encoding for Uniquefile is not important here because the caller writes to it as it sees fit
      if staging_location
        tempfile = Puppet::FileSystem::Uniquefile.new(Puppet::FileSystem.basename_string(file), staging_location)
      else
        tempfile = Puppet::FileSystem::Uniquefile.new(Puppet::FileSystem.basename_string(file), Puppet::FileSystem.dir_string(file))
      end

      effective_mode =
        unless Puppet::Util::Platform.windows?
          # Grab the current file mode, and fall back to the defaults.

          if Puppet::FileSystem.exist?(file)
            stat = Puppet::FileSystem.lstat(file)
            tempfile.chown(stat.uid, stat.gid)
            stat.mode
          else
            mode
          end
        end

      # OK, now allow the caller to write the content of the file.
      yield tempfile

      if effective_mode
        # We only care about the bottom four slots, which make the real mode,
        # and not the rest of the platform stat call fluff and stuff.
        tempfile.chmod(effective_mode & 0o7777)
      end

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

      if validate_callback
        validate_callback.call(tempfile.path)
      end

      if Puppet::Util::Platform.windows?
        # Windows ReplaceFile needs a file to exist, so touch handles this
        unless Puppet::FileSystem.exist?(file)
          Puppet::FileSystem.touch(file)
          if mode
            Puppet::Util::Windows::Security.set_mode(mode, Puppet::FileSystem.path_string(file))
          end
        end
        # Yes, the arguments are reversed compared to the rename in the rest
        # of the world.
        Puppet::Util::Windows::File.replace_file(FileSystem.path_string(file), tempfile.path)

      else
        # MRI Ruby checks for this and raises an error, while JRuby removes the directory
        # and replaces it with a file. This makes the our version of replace_file() consistent
        if Puppet::FileSystem.exist?(file) && Puppet::FileSystem.directory?(file)
          raise Errno::EISDIR, _("Is a directory: %{directory}") % { directory: file }
        end

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
    # puts err.inspect
    # puts Puppet::Util.pretty_backtrace(err.backtrace)
    Puppet.log_exception(err, "#{message}: #{err}")
    Puppet::Util::Log.force_flushqueue()
    exit(code)
  end
  module_function :exit_on_fail

  def deterministic_rand(seed, max)
    deterministic_rand_int(seed, max).to_s
  end
  module_function :deterministic_rand

  def deterministic_rand_int(seed, max)
    Random.new(seed).rand(max)
  end
  module_function :deterministic_rand_int

  # Executes a block of code, wrapped around Facter.load_external(false) and
  # Facter.load_external(true) which will cause Facter to not evaluate external facts.
  def skip_external_facts
    return yield unless Puppet.runtime[:facter].load_external?

    begin
      Puppet.runtime[:facter].load_external(false)
      yield
    ensure
      Puppet.runtime[:facter].load_external(true)
    end
  end
  module_function :skip_external_facts
end
end

require_relative 'util/errors'
require_relative 'util/metaid'
require_relative 'util/classgen'
require_relative 'util/docs'
require_relative 'util/execution'
require_relative 'util/logging'
require_relative 'util/package'
require_relative 'util/warnings'
