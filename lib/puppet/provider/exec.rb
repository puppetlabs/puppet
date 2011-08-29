class Puppet::Provider::Exec < Puppet::Provider
  include Puppet::Util::Execution

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

        environment[:PATH] = resource[:path].join(File::PATH_SEPARATOR) if resource[:path]

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
              run_and_capture(command, resource[:user], resource[:group])
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
    self.fail "'#{command}' is not qualified and no path was specified. Please qualify the command or specify a path." if !absolute_path?(exe) and resource[:path].nil?
  end
end
