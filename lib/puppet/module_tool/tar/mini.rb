class Puppet::ModuleTool::Tar::Mini
  def unpack(sourcefile, destdir, _)
    Zlib::GzipReader.open(sourcefile) do |reader|
      Archive::Tar::Minitar.unpack(reader, destdir, find_valid_files(reader)) do |action, name, stats|
        case action
        when :dir
          validate_entry(destdir, name)
          set_dir_mode!(stats)
          Puppet.debug("Extracting: #{destdir}/#{name}")
        when :file_start
          # Octal string of the old file mode.
          validate_entry(destdir, name)
          set_file_mode!(stats)
          Puppet.debug("Extracting: #{destdir}/#{name}")
        end
        set_default_user_and_group!(stats)
        stats
      end
    end
  end

  def pack(sourcedir, destfile)
    Zlib::GzipWriter.open(destfile) do |writer|
      Archive::Tar::Minitar.pack(sourcedir, writer) do |step, name, stats|
        # TODO smcclellan 2017-10-31 Set permissions here when this yield block
        # executes before the header is written. As it stands, the `stats`
        # argument isn't mutable in a way that will effect the desired mode for
        # the file.
      end
    end
  end

  private

  EXECUTABLE = 0755
  NOT_EXECUTABLE = 0644
  USER_EXECUTE = 0100

  def set_dir_mode!(stats)
    if stats.key?(:mode)
      # This is only the case for `pack`, so this code will not run.
      stats[:mode] = EXECUTABLE
    elsif stats.key?(:entry)
      old_mode = stats[:entry].instance_variable_get(:@mode)
      if old_mode.is_a?(Integer)
        stats[:entry].instance_variable_set(:@mode, EXECUTABLE)
      end
    end
  end

  # Sets a file mode to 0755 if the file is executable by the user.
  # Sets a file mode to 0644 if the file mode is set (non-Windows).
  def sanitized_mode(old_mode)
    old_mode & USER_EXECUTE != 0 ? EXECUTABLE : NOT_EXECUTABLE
  end

  def set_file_mode!(stats)
    if stats.key?(:mode)
      # This is only the case for `pack`, so this code will not run.
      stats[:mode] = sanitized_mode(stats[:mode])
    elsif stats.key?(:entry)
      old_mode = stats[:entry].instance_variable_get(:@mode)
      # If the user can execute the file, set 0755, otherwise 0644.
      if old_mode.is_a?(Integer)
        new_mode = sanitized_mode(old_mode)
        stats[:entry].instance_variable_set(:@mode, new_mode)
      end
    end
  end

  # Sets UID and GID to 0 for standardization.
  def set_default_user_and_group!(stats)
    stats[:uid] = 0
    stats[:gid] = 0
  end

  # Find all the valid files in tarfile.
  #
  # This check was mainly added to ignore 'x' and 'g' flags from the PAX
  # standard but will also ignore any other non-standard tar flags.
  # tar format info: https://pic.dhe.ibm.com/infocenter/zos/v1r13/index.jsp?topic=%2Fcom.ibm.zos.r13.bpxa500%2Ftaf.htm
  # pax format info: https://pic.dhe.ibm.com/infocenter/zos/v1r13/index.jsp?topic=%2Fcom.ibm.zos.r13.bpxa500%2Fpxarchfm.htm
  def find_valid_files(tarfile)
    Archive::Tar::Minitar.open(tarfile).collect do |entry|
      flag = entry.typeflag
      if flag.nil? || flag =~ /[[:digit:]]/ && (0..7).include?(flag.to_i)
        entry.full_name
      else
        Puppet.debug "Invalid tar flag '#{flag}' will not be extracted: #{entry.name}"
        next
      end
    end
  end

  def validate_entry(destdir, path)
    if Pathname.new(path).absolute?
      raise Puppet::ModuleTool::Errors::InvalidPathInPackageError, :entry_path => path, :directory => destdir
    end

    path = File.expand_path File.join(destdir, path)

    if path !~ /\A#{Regexp.escape destdir}/
      raise Puppet::ModuleTool::Errors::InvalidPathInPackageError, :entry_path => path, :directory => destdir
    end
  end
end
