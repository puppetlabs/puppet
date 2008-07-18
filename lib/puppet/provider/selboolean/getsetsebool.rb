Puppet::Type.type(:selboolean).provide(:getsetsebool) do
    desc "Manage SELinux booleans using the getsebool and setsebool binaries."

    commands :getsebool => "/usr/sbin/getsebool"
    commands :setsebool => "/usr/sbin/setsebool"

    def value
        self.debug "Retrieving value of selboolean #{@resource[:name]}"

        status = getsebool(@resource[:name])

        if status =~ / off$/ then
            return :off
        elsif status =~ / on$/ then
            return :on
        else
            status.chomp!
            raise Puppet::Error, "Invalid response '%s' returned from getsebool" % [status]
        end
    end

    def value=(new)
        persist = ""
        if @resource[:persistent] == :true
            self.debug "Enabling persistence"
            persist = "-P"
        end
        execoutput("#{command(:setsebool)} #{persist} #{@resource[:name]} #{new}")
        return :file_changed
    end

    # Required workaround, since SELinux policy prevents setsebool
    # from writing to any files, even tmp, preventing the standard
    # 'setsebool("...")' construct from working.

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
end
