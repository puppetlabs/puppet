# frozen_string_literal: true

require_relative '../../puppet/provider'
require_relative '../../puppet/util/execution'

class Puppet::Provider::Exec < Puppet::Provider
  include Puppet::Util::Execution

  def environment
    env = {}

    if (path = resource[:path])
      env[:PATH] = path.join(File::PATH_SEPARATOR)
    end

    return env unless (envlist = resource[:environment])

    envlist = [envlist] unless envlist.is_a? Array
    envlist.each do |setting|
      unless (match = /^(\w+)=((.|\n)*)$/.match(setting))
        warning _("Cannot understand environment setting %{setting}") % { setting: setting.inspect }
        next
      end
      var = match[1]
      value = match[2]

      if env.include?(var) || env.include?(var.to_sym)
        warning _("Overriding environment setting '%{var}' with '%{value}'") % { var: var, value: value }
      end

      if value.nil? || value.empty?
        msg = _("Empty environment setting '%{var}'") % { var: var }
        Puppet.warn_once('undefined_variables', "empty_env_var_#{var}", msg, resource.file, resource.line)
      end

      env[var] = value
    end

    env
  end

  def run(command, check = false)
    output = nil
    sensitive = resource.parameters[:command].sensitive

    checkexe(command)

    debug "Executing#{check ? ' check' : ''} '#{sensitive ? '[redacted]' : command}'"

    # Ruby 2.1 and later interrupt execution in a way that bypasses error
    # handling by default. Passing Timeout::Error causes an exception to be
    # raised that can be rescued inside of the block by cleanup routines.
    #
    # This is backwards compatible all the way to Ruby 1.8.7.
    Timeout.timeout(resource[:timeout], Timeout::Error) do
      cwd = resource[:cwd]
      # It's ok if cwd is nil. In that case Puppet::Util::Execution.execute() simply will not attempt to
      # change the working directory, which is exactly the right behavior when no cwd parameter is
      # expressed on the resource.  Moreover, attempting to change to the directory that is already
      # the working directory can fail under some circumstances, so avoiding the directory change attempt
      # is preferable to defaulting cwd to that directory.

      # note that we are passing "false" for the "override_locale" parameter, which ensures that the user's
      # default/system locale will be respected.  Callers may override this behavior by setting locale-related
      # environment variables (LANG, LC_ALL, etc.) in their 'environment' configuration.
      output = Puppet::Util::Execution.execute(
        command,
        :failonfail => false,
        :combine => true,
        :cwd => cwd,
        :uid => resource[:user], :gid => resource[:group],
        :override_locale => false,
        :custom_environment => environment(),
        :sensitive => sensitive
      )
    end
    # The shell returns 127 if the command is missing.
    if output.exitstatus == 127
      raise ArgumentError, output
    end

    # Return output twice as processstatus was returned before, but only exitstatus was ever called.
    # Output has the exitstatus on it so it is returned instead. This is here twice as changing this
    #  would result in a change to the underlying API.
    [output, output]
  end

  def extractexe(command)
    if command.is_a? Array
      command.first
    else
      match = /^"([^"]+)"|^'([^']+)'/.match(command)
      if match
        # extract whichever of the two sides matched the content.
        match[1] or match[2]
      else
        command.split(/ /)[0]
      end
    end
  end

  def validatecmd(command)
    exe = extractexe(command)
    # if we're not fully qualified, require a path
    self.fail _("'%{exe}' is not qualified and no path was specified. Please qualify the command or specify a path.") % { exe: exe } if !absolute_path?(exe) and resource[:path].nil?
  end
end
