require 'puppet/parameter/boolean'

Puppet::Type.newtype(:tidy) do
  require 'puppet/file_serving/fileset'
  require 'puppet/file_bucket/dipper'

  @doc = "Remove unwanted files based on specific criteria.  Multiple
    criteria are OR'd together, so a file that is too large but is not
    old enough will still get tidied.

    If you don't specify either `age` or `size`, then all files will
    be removed.

    This resource type works by generating a file resource for every file
    that should be deleted and then letting that resource perform the
    actual deletion.
    "

  newparam(:path) do
    desc "The path to the file or directory to manage.  Must be fully
      qualified."
    isnamevar
    munge do |value|
      File.expand_path(value)
    end
  end

  newparam(:recurse) do
    desc "If target is a directory, recursively descend
      into the directory looking for files to tidy."

    newvalues(:true, :false, :inf, /^[0-9]+$/)

    # Replace the validation so that we allow numbers in
    # addition to string representations of them.
    validate { |arg| }
    munge do |value|
      newval = super(value)
      case newval
      when :true, :inf; true
      when :false; false
      when Integer, Fixnum, Bignum; value
      when /^\d+$/; Integer(value)
      else
        raise ArgumentError, "Invalid recurse value #{value.inspect}"
      end
    end
  end

  newparam(:matches) do
    desc <<-'EOT'
      One or more (shell type) file glob patterns, which restrict
      the list of files to be tidied to those whose basenames match
      at least one of the patterns specified. Multiple patterns can
      be specified using an array.

      Example:

          tidy { '/tmp':
            age     => '1w',
            recurse => 1,
            matches => [ '[0-9]pub*.tmp', '*.temp', 'tmpfile?' ],
          }

      This removes files from `/tmp` if they are one week old or older,
      are not in a subdirectory and match one of the shell globs given.

      Note that the patterns are matched against the basename of each
      file -- that is, your glob patterns should not have any '/'
      characters in them, since you are only specifying against the last
      bit of the file.

      Finally, note that you must now specify a non-zero/non-false value
      for recurse if matches is used, as matches only apply to files found
      by recursion (there's no reason to use static patterns match against
      a statically determined path).  Requiering explicit recursion clears
      up a common source of confusion.
    EOT

    # Make sure we convert to an array.
    munge do |value|
      fail "Tidy can't use matches with recurse 0, false, or undef" if "#{@resource[:recurse]}" =~ /^(0|false|)$/
      [value].flatten
    end

    # Does a given path match our glob patterns, if any?  Return true
    # if no patterns have been provided.
    def tidy?(path, stat)
      basename = File.basename(path)
      flags = File::FNM_DOTMATCH | File::FNM_PATHNAME
      return(value.find {|pattern| File.fnmatch(pattern, basename, flags) } ? true : false)
    end
  end

  newparam(:backup) do
    desc "Whether tidied files should be backed up.  Any values are passed
      directly to the file resources used for actual file deletion, so consult
      the `file` type's backup documentation to determine valid values."
  end

  newparam(:age) do
    desc "Tidy files whose age is equal to or greater than
      the specified time.  You can choose seconds, minutes,
      hours, days, or weeks by specifying the first letter of any
      of those words (e.g., '1w').

      Specifying 0 will remove all files."

    AgeConvertors = {
      :s => 1,
      :m => 60,
      :h => 60 * 60,
      :d => 60 * 60 * 24,
      :w => 60 * 60 * 24 * 7,
    }

    def convert(unit, multi)
      if num = AgeConvertors[unit]
        return num * multi
      else
        self.fail "Invalid age unit '#{unit}'"
      end
    end

    def tidy?(path, stat)
      # If the file's older than we allow, we should get rid of it.
      (Time.now.to_i - stat.send(resource[:type]).to_i) > value
    end

    munge do |age|
      unit = multi = nil
      case age
      when /^([0-9]+)(\w)\w*$/
        multi = Integer($1)
        unit = $2.downcase.intern
      when /^([0-9]+)$/
        multi = Integer($1)
        unit = :d
      else
        self.fail "Invalid tidy age #{age}"
      end

      convert(unit, multi)
    end
  end

  newparam(:size) do
    desc "Tidy files whose size is equal to or greater than
      the specified size.  Unqualified values are in kilobytes, but
      *b*, *k*, *m*, *g*, and *t* can be appended to specify *bytes*,
      *kilobytes*, *megabytes*, *gigabytes*, and *terabytes*, respectively.
      Only the first character is significant, so the full word can also
      be used."

    def convert(unit, multi)
      if num = { :b => 0, :k => 1, :m => 2, :g => 3, :t => 4 }[unit]
        result = multi
        num.times do result *= 1024 end
        return result
      else
        self.fail "Invalid size unit '#{unit}'"
      end
    end

    def tidy?(path, stat)
      stat.size >= value
    end

    munge do |size|
      case size
      when /^([0-9]+)(\w)\w*$/
        multi = Integer($1)
        unit = $2.downcase.intern
      when /^([0-9]+)$/
        multi = Integer($1)
        unit = :k
      else
        self.fail "Invalid tidy size #{age}"
      end

      convert(unit, multi)
    end
  end

  newparam(:type) do
    desc "Set the mechanism for determining age. Default: atime."

    newvalues(:atime, :mtime, :ctime)

    defaultto :atime
  end

  newparam(:rmdirs, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Tidy directories in addition to files; that is, remove
      directories whose age is older than the specified criteria.
      This will only remove empty directories, so all contained
      files must also be tidied before a directory gets removed."
  end

  # Erase PFile's validate method
  validate do
  end

  def self.instances
    []
  end

  def depthfirst?
    true
  end

  def initialize(hash)
    super

    # only allow backing up into filebuckets
    self[:backup] = false unless self[:backup].is_a? Puppet::FileBucket::Dipper
  end

  # Make a file resource to remove a given file.
  def mkfile(path)
    # Force deletion, so directories actually get deleted.
    Puppet::Type.type(:file).new :path => path, :backup => self[:backup], :ensure => :absent, :force => true
  end

  def retrieve
    # Our ensure property knows how to retrieve everything for us.
    if obj = @parameters[:ensure]
      return obj.retrieve
    else
      return {}
    end
  end

  # Hack things a bit so we only ever check the ensure property.
  def properties
    []
  end

  def generate
    return [] unless stat(self[:path])

    case self[:recurse]
    when Integer, Fixnum, Bignum, /^\d+$/
      parameter = { :recurse => true, :recurselimit => self[:recurse] }
    when true, :true, :inf
      parameter = { :recurse => true }
    end

    if parameter
      files = Puppet::FileServing::Fileset.new(self[:path], parameter).files.collect do |f|
        f == "." ? self[:path] : ::File.join(self[:path], f)
      end
    else
      files = [self[:path]]
    end
    found_files = files.find_all { |path| tidy?(path) }.collect { |path| mkfile(path) }
    result = found_files.each { |file| debug "Tidying #{file.ref}" }.sort { |a,b| b[:path] <=> a[:path] }
    notice "Tidying #{found_files.size} files"

    # No need to worry about relationships if we don't have rmdirs; there won't be
    # any directories.
    return result unless rmdirs?

    # Now make sure that all directories require the files they contain, if all are available,
    # so that a directory is emptied before we try to remove it.
    files_by_name = result.inject({}) { |hash, file| hash[file[:path]] = file; hash }

    files_by_name.keys.sort { |a,b| b <=> a }.each do |path|
      dir = ::File.dirname(path)
      next unless resource = files_by_name[dir]
      if resource[:require]
        resource[:require] << Puppet::Resource.new(:file, path)
      else
        resource[:require] = [Puppet::Resource.new(:file, path)]
      end
    end

    result
  end

  # Does a given path match our glob patterns, if any?  Return true
  # if no patterns have been provided.
  def matches?(path)
    return true unless self[:matches]

    basename = File.basename(path)
    flags = File::FNM_DOTMATCH | File::FNM_PATHNAME
    if self[:matches].find {|pattern| File.fnmatch(pattern, basename, flags) }
      return true
    else
      debug "No specified patterns match #{path}, not tidying"
      return false
    end
  end

  # Should we remove the specified file?
  def tidy?(path)
    return false unless stat = self.stat(path)

    return false if stat.ftype == "directory" and ! rmdirs?

    # The 'matches' parameter isn't OR'ed with the other tests --
    # it's just used to reduce the list of files we can match.
    return false if param = parameter(:matches) and ! param.tidy?(path, stat)

    tested = false
    [:age, :size].each do |name|
      next unless param = parameter(name)
      tested = true
      return true if param.tidy?(path, stat)
    end

    # If they don't specify either, then the file should always be removed.
    return true unless tested
    false
  end

  def stat(path)
    begin
      Puppet::FileSystem.lstat(path)
    rescue Errno::ENOENT => error
      info "File does not exist"
      return nil
    rescue Errno::EACCES => error
      warning "Could not stat; permission denied"
      return nil
    end
  end
end
