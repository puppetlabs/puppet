require_relative '../../puppet/file_system'
require 'delegate'
require 'tmpdir'

# A class that provides `Tempfile`-like capabilities, but does not attempt to
# manage the deletion of the file for you.  API is identical to the
# normal `Tempfile` class.
#
# @api public
class Puppet::FileSystem::Uniquefile < DelegateClass(File)
  # Convenience method which ensures that the file is closed and
  # unlinked before returning
  #
  # @param identifier [String] additional part of generated pathname
  # @yieldparam file [File] the temporary file object
  # @return result of the passed block
  # @api private
  def self.open_tmp(identifier)
    f = new(identifier)
    yield f
  ensure
    if f
      f.close!
    end
  end

  # we require a basename unlike Tempfile
  def initialize(basename, tmpdir=nil, mode: 0, **options)
    @unlinked = false
    @mode = mode|File::RDWR|File::CREAT|File::EXCL
    create_tmpname(basename, tmpdir, mode, options) do |tmpname, n, opts|
      opts[:perm] = 0600
      self.class.locking(tmpname) do
        @tmpfile = File.open(tmpname, @mode, **opts)
      end
      @opts = opts.freeze
    end

    super(@tmpfile)
  end

  # Opens or reopens the file with mode "r+".
  def open
    _close
    mode = @mode & ~(File::CREAT|File::EXCL)
    @tmpfile = File.open(@tmpfile.path, mode, @opts)
    __setobj__(@tmpfile)
  end

  def _close
    @tmpfile.close
  end
  protected :_close

  def close(unlink_now=false)
    _close
    unlink if unlink_now
  end

  def close!
    close(true)
  end

  def unlink
    return if @unlinked
    begin
      File.unlink(@tmpfile.path)
    rescue Errno::ENOENT
    rescue Errno::EACCES
      # may not be able to unlink on Windows; just ignore
      return
    end
    @unlinked = true
  end
  alias delete unlink

  # Returns the full path name of the temporary file.
  # This will be nil if #unlink has been called.
  def path
    @unlinked ? nil : @tmpfile.path
  end

  private

  def make_tmpname(prefix_suffix, n)
    case prefix_suffix
      when String
        prefix = prefix_suffix
        suffix = ""
      when Array
        prefix = prefix_suffix[0]
        suffix = prefix_suffix[1]
      else
        raise ArgumentError, _("unexpected prefix_suffix: %{value}") % { value: prefix_suffix.inspect }
    end
    t = Time.now.strftime("%Y%m%d")
    path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
    path << "-#{n}" if n
    path << suffix
  end

  def create_tmpname(basename, *rest)
    opts = try_convert_to_hash(rest[-1])
    if opts
      opts = opts.dup if rest.pop.equal?(opts)
      max_try = opts.delete(:max_try)
      opts = [opts]
    else
      opts = []
    end
    tmpdir, = *rest
    tmpdir ||= tmpdir()
    n = nil
    begin
      path = File.expand_path(make_tmpname(basename, n), tmpdir)
      yield(path, n, *opts)
    rescue Errno::EEXIST
      n ||= 0
      n += 1
      retry if !max_try or n < max_try
      raise _("cannot generate temporary name using `%{basename}' under `%{tmpdir}'") % { basename: basename, tmpdir: tmpdir }
    end
    path
  end

  def try_convert_to_hash(h)
    begin
      h.to_hash
    rescue NoMethodError
      nil
    end
  end

  @@systmpdir ||= defined?(Etc.systmpdir) ? Etc.systmpdir : '/tmp'

  def tmpdir
    tmp = nil
    [Puppet::Util.get_env('TMPDIR'), Puppet::Util.get_env('TMP'), Puppet::Util.get_env('TEMP'), @@systmpdir, '/tmp'].each do |dir|
      next if !dir
      dir = File.expand_path(dir)
      stat = File.stat(dir)
      if stat && stat.directory? && stat.writable? &&
         (!stat.world_writable? || stat.sticky?)
        tmp = dir
        break
      end rescue nil
    end
    raise ArgumentError, "could not find a temporary directory" unless tmp
    tmp
  end

  class << self
    # yields with locking for +tmpname+ and returns the result of the
    # block.
    def locking(tmpname)
      lock = tmpname + '.lock'
      mkdir(lock)
      yield
    rescue Errno::ENOENT => e
      ex = Errno::ENOENT.new("A directory component in #{lock} does not exist or is a dangling symbolic link")
      ex.set_backtrace(e.backtrace)
      raise ex
    ensure
      rmdir(lock) if Puppet::FileSystem.exist?(lock)
    end

    def mkdir(*args)
      Dir.mkdir(*args)
    end

    def rmdir(*args)
      Dir.rmdir(*args)
    end
  end

end
