Puppet::Type.type(:selmodule).provide(:semodule) do
  desc "Manage SELinux policy modules using the semodule binary."

  commands :semodule => "/usr/sbin/semodule"

  def create
    begin
      execoutput("#{command(:semodule)} --install #{selmod_name_to_filename}")
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not load policy module: #{detail}", detail.backtrace
    end
    :true
  end

  def destroy
      execoutput("#{command(:semodule)} --remove #{@resource[:name]}")
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not remove policy module: #{detail}", detail.backtrace
  end

  def exists?
    self.debug "Checking for module #{@resource[:name]}"
    execpipe("#{command(:semodule)} --list") do |out|
      out.each_line do |line|
        if line =~ /#{@resource[:name]}\b/
          return :true
        end
      end
    end
    nil
  end

  def syncversion
    self.debug "Checking syncversion on #{@resource[:name]}"

    loadver = selmodversion_loaded

    if(loadver) then
      filever = selmodversion_file
      if (filever == loadver)
        return :true
      end
    end
    :false
  end

  def syncversion= (dosync)
      execoutput("#{command(:semodule)} --upgrade #{selmod_name_to_filename}")
  rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not upgrade policy module: #{detail}", detail.backtrace
  end

  # Helper functions

  def execoutput (cmd)
    output = ''
    begin
      execpipe(cmd) do |out|
        output = out.readlines.join('').chomp!
      end
    rescue Puppet::ExecutionFailure
      raise Puppet::ExecutionFailure, output.split("\n")[0], $!.backtrace
    end
    output
  end

  def selmod_name_to_filename
    if @resource[:selmodulepath]
      return @resource[:selmodulepath]
    else
      return "#{@resource[:selmoduledir]}/#{@resource[:name]}.pp"
    end
  end

  def selmod_readnext (handle)
    len = handle.read(4).unpack('V')[0]
    handle.read(len)
  end

  def selmodversion_file
    magic = 0xF97CFF8F
    v = nil

    filename = selmod_name_to_filename
    # Open a file handle and parse the bytes until version is found
    Puppet::FileSystem.open(filename, nil, 'rb') do |mod|

      (hdr, ver, numsec) = mod.read(12).unpack('VVV')

      raise Puppet::Error, "Found #{hdr} instead of magic #{magic} in #{filename}" if hdr != magic

      raise Puppet::Error, "Unknown policy file version #{ver} in #{filename}" if ver != 1

      # Read through (and throw away) the file section offsets, and also
      # the magic header for the first section.

      mod.read((numsec + 1) * 4)

      ## Section 1 should be "SE Linux Module"

      selmod_readnext(mod)
      selmod_readnext(mod)

      # Skip past the section headers
      mod.read(14)

      # Module name
      selmod_readnext(mod)

      # At last!  the version

      v = selmod_readnext(mod)

    end

    self.debug "file version #{v}"
    v
  end

  def selmodversion_loaded
    selmod_output = []
    selmodule_cmd = "#{command(:semodule)} --list"
    begin
      execpipe(selmodule_cmd) do |output|
        output.each_line do |line|
          line.chomp!
          selmod_output << line
          bits = line.split
          if bits[0] == @resource[:name]
            self.debug "load version #{bits[1]}"
            return bits[1]
          end
        end
      end
    rescue Puppet::ExecutionFailure
      raise Puppet::ExecutionFailure, _("Could not list policy modules: \"%{selmodule_command}\" failed with \"%{selmod_output}\"") % { selmodule_command: selmodule_cmd, selmod_output: selmod_output.join(' ') }
    end
    nil
  end
end
