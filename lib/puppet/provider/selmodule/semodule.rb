Puppet::Type.type(:selmodule).provide(:semodule) do
    desc "Manage SELinux policy modules using the semodule binary."

    commands :semodule => "/usr/sbin/semodule"

    def create
        begin
            execoutput("#{command(:semodule)} --install #{selmod_name_to_filename}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not load policy module: %s" % [detail];
        end
        return :true
    end

    def destroy
        begin
            execoutput("#{command(:semodule)} --remove #{@resource[:name]}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not remove policy module: %s" % [detail];
        end
    end

    def exists?
        self.debug "Checking for module #{@resource[:name]}"
        execpipe("#{command(:semodule)} --list") do |out|
            out.each do |line|
                if line =~ /#{@resource[:name]}\b/
                        return :true
                end
            end
        end
        return nil
    end

    def syncversion
        self.debug "Checking syncversion on #{@resource[:name]}"

        loadver = selmodversion_loaded

        if(loadver) then
            filever = selmodversion_file
            if (filever == loadver) then
                return :true
            end
        end
        return :false
    end

    def syncversion= (dosync)
        begin
            execoutput("#{command(:semodule)} --upgrade #{selmod_name_to_filename}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not upgrade policy module: %s" % [detail];
        end
    end

    # Helper functions

    def execoutput (cmd)
      output = ''
      begin
        execpipe(cmd) do |out|
          output = out.readlines.join('').chomp!
        end
      rescue Puppet::ExecutionFailure
        raise Puppet::ExecutionFailure, output.split("\n")[0]
      end
      return output
    end

    def selmod_name_to_filename
        if @resource[:selmodulepath]
            return @resource[:selmodulepath]
        else
            return "#{@resource[:selmoduledir]}/#{@resource[:name]}.pp"
        end
    end

    def selmod_readnext (handle)
        len = handle.read(4).unpack('L')[0]
        return handle.read(len)
    end

    def selmodversion_file
        magic = 0xF97CFF8F

        filename = selmod_name_to_filename
        mod = File.new(filename, "r")

        (hdr, ver, numsec) = mod.read(12).unpack('LLL')

        if hdr != magic
            raise Puppet::Error, "Found #{hdr} instead of magic #{magic} in #{filename}"
        end

        if ver != 1
            raise Puppet::Error, "Unknown policy file version #{ver} in #{filename}"
        end

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

        self.debug "file version #{v}"
        return v
    end

    def selmodversion_loaded
        lines = ()
        begin
            execpipe("#{command(:semodule)} --list") do |output|
                lines = output.readlines
                lines.each do |line|
                    line.chomp!
                    bits = line.split
                    if bits[0] == @resource[:name] then
                        self.debug "load version #{bits[1]}"
                        return bits[1]
                    end
                end
            end
        rescue Puppet::ExecutionFailure
            raise Puppet::ExecutionFailure, "Could not list policy modules: %s" % [lines.join(' ').chomp!]
        end
        return nil
    end
end
