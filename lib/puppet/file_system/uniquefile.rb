require 'puppet/file_system'
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

  def initialize(basename, *rest)
    create_tmpname(basename, *rest) do |tmpname, n, opts|
      mode = File::RDWR|File::CREAT|File::EXCL
      perm = 0600
      if opts
        mode |= opts.delete(:mode) || 0
        opts[:perm] = perm
        perm = nil
      else
        opts = perm
      end
      self.class.locking(tmpname) do
        @tmpfile = File.open(tmpname, mode, opts)
        @tmpname = tmpname
      end
      @mode = mode & ~(File::CREAT|File::EXCL)
      perm or opts.freeze
      @opts = opts
    end

    super(@tmpfile)
  end

  # Opens or reopens the file with mode "r+".
  def open
    @tmpfile.close if @tmpfile
    @tmpfile = File.open(@tmpname, @mode, @opts)
    __setobj__(@tmpfile)
  end

  def _close
    begin
      @tmpfile.close if @tmpfile
    ensure
      @tmpfile = nil
    end
  end
  protected :_close

  def close(unlink_now=false)
    if unlink_now
      close!
    else
      _close
    end
  end

  def close!
    _close
    unlink
  end

  def unlink
    return unless @tmpname
    begin
      File.unlink(@tmpname)
    rescue Errno::ENOENT
    rescue Errno::EACCES
      # may not be able to unlink on Windows; just ignore
      return
    end
    @tmpname = nil
  end
  alias delete unlink

  # Returns the full path name of the temporary file.
  # This will be nil if #unlink has been called.
  def path
    @tmpname
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
    if opts = try_convert_to_hash(rest[-1])
      opts = opts.dup if rest.pop.equal?(opts)
      max_try = opts.delete(:max_try)
      opts = [opts]
    else
      opts = []
    end
    tmpdir, = *rest
    if $SAFE > 0 and tmpdir.tainted?
      tmpdir = '/tmp'
    else
      tmpdir ||= tmpdir()
    end
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
    tmp = '.'
    if $SAFE > 0
      @@systmpdir
    else
      for dir in [ Puppet::Util.get_env('TMPDIR'), Puppet::Util.get_env('TMP'), Puppet::Util.get_env('TEMP'), @@systmpdir, '/tmp']
        if dir and stat = File.stat(dir) and stat.directory? and stat.writable?
          tmp = dir
          break
        end rescue nil
      end
      File.expand_path(tmp)
    end
  end


  class << self
    # yields with locking for +tmpname+ and returns the result of the
    # block.
    def locking(tmpname)
      lock = tmpname + '.lock'
      mkdir(lock)
      yield
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
