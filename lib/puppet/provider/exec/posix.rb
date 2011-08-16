Puppet::Type.type(:exec).provide :posix do
  include Puppet::Util::Execution

  confine :feature => :posix
  defaultfor :feature => :posix

  desc <<-EOT
    Executes external binaries directly, without passing through a shell or
    performing any interpolation. This is a safer and more predictable way
    to execute most commands, but prevents the use of globbing and shell
    built-ins (including control logic like "for" and "if" statements).
  EOT

  def run(command, check = false)
    output = nil
    status = nil
    dir = nil

    checkexe(command)

    if dir = resource[:cwd]
      unless File.directory?(dir)
        if check
          dir = nil
        else
          self.fail "Working directory '#{dir}' does not exist"
        end
      end
    end

    dir ||= Dir.pwd

    debug "Executing#{check ? " check": ""} '#{command}'"
    begin
      # Do our chdir
      Dir.chdir(dir) do
        environment = {}

        environment[:PATH] = resource[:path].join(":") if resource[:path]

        if envlist = resource[:environment]
          envlist = [envlist] unless envlist.is_a? Array
          envlist.each do |setting|
            if setting =~ /^(\w+)=((.|\n)+)$/
              env_name = $1
              value = $2
              if environment.include?(env_name) || environment.include?(env_name.to_sym)
                warning "Overriding environment setting '#{env_name}' with '#{value}'"
              end
              environment[env_name] = value
            else
              warning "Cannot understand environment setting #{setting.inspect}"
            end
          end
        end

        withenv environment do
          Timeout::timeout(resource[:timeout]) do
            output, status = Puppet::Util::SUIDManager.
              run_and_capture([command], resource[:user], resource[:group])
          end
          # The shell returns 127 if the command is missing.
          if status.exitstatus == 127
            raise ArgumentError, output
          end
        end
      end
    rescue Errno::ENOENT => detail
      self.fail detail.to_s
    end

    return output, status
  end

  # Verify that we have the executable
  def checkexe(command)
    exe = extractexe(command)

    if File.expand_path(exe) == exe
      if !File.exists?(exe)
        raise ArgumentError, "Could not find command '#{exe}'"
      elsif !File.file?(exe)
        raise ArgumentError, "'#{exe}' is a #{File.ftype(exe)}, not a file"
      elsif !File.executable?(exe)
        raise ArgumentError, "'#{exe}' is not executable"
      end
      return
    end

    if resource[:path]
      withenv :PATH => resource[:path].join(File::PATH_SEPARATOR) do
        return if which(exe)
      end
    end

    # 'which' will only return the command if it's executable, so we can't
    # distinguish not found from not executable
    raise ArgumentError, "Could not find command '#{exe}'"
  end

  def extractexe(command)
    # easy case: command was quoted
    if command =~ /^"([^"]+)"/
      $1
    else
      command.split(/ /)[0]
    end
  end

  def validatecmd(command)
    exe = extractexe(command)
    # if we're not fully qualified, require a path
    self.fail "'#{command}' is not qualified and no path was specified. Please qualify the command or specify a path." if File.expand_path(exe) != exe and resource[:path].nil?
  end
end
