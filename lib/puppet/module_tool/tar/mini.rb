class Puppet::ModuleTool::Tar::Mini
  def unpack(sourcefile, destdir, _)
    Zlib::GzipReader.open(sourcefile) do |reader|
      Archive::Tar::Minitar.unpack(reader, destdir, find_valid_files(reader)) do |action, name, stats|
        case action
        when :file_done
          File.chmod(0644, "#{destdir}/#{name}")
        when :dir, :file_start
          validate_entry(destdir, name)
          Puppet.debug("Extracting: #{destdir}/#{name}")
        end
      end
    end
  end

  def pack(sourcedir, destfile)
    Zlib::GzipWriter.open(destfile) do |writer|
      Archive::Tar::Minitar.pack(sourcedir, writer)
    end
  end

  private

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
