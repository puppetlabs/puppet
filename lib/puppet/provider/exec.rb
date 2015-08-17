require 'puppet/provider'
require 'puppet/util/execution'

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

        # Ruby 2.1 and later interrupt execution in a way that bypasses error
        # handling by default. Passing Timeout::Error causes an exception to be
        # raised that can be rescued inside of the block by cleanup routines.
        #
        # This is backwards compatible all the way to Ruby 1.8.7.
        Timeout::timeout(resource[:timeout], Timeout::Error) do
          # note that we are passing "false" for the "override_locale" parameter, which ensures that the user's
          # default/system locale will be respected.  Callers may override this behavior by setting locale-related
          # environment variables (LANG, LC_ALL, etc.) in their 'environment' configuration.
          output = Puppet::Util::Execution.execute(command, :failonfail => false, :combine => true,
                                  :uid => resource[:user], :gid => resource[:group],
                                  :override_locale => false,
                                  :custom_environment => environment)
        end
        # The shell returns 127 if the command is missing.
        if output.exitstatus == 127
          raise ArgumentError, output
        end

      end
    rescue Errno::ENOENT => detail
      self.fail Puppet::Error, detail.to_s, detail
    end

    # Return output twice as processstatus was returned before, but only exitstatus was ever called.
    # Output has the exitstatus on it so it is returned instead. This is here twice as changing this
    #  would result in a change to the underlying API.
    return output, output
  end

  def extractexe(command)
    if command.is_a? Array
      command.first
    elsif match = /^"([^"]+)"|^'([^']+)'/.match(command)
      # extract whichever of the two sides matched the content.
      match[1] or match[2]
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
