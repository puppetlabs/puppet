require 'puppet/provider/exec'

Puppet::Type.type(:exec).provide :windows, :parent => Puppet::Provider::Exec do

  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  desc <<-'EOT'
    Execute external binaries on Windows systems. As with the `posix`
    provider, this provider directly calls the command with the arguments
    given, without passing it through a shell or performing any interpolation.
    To use shell built-ins --- that is, to emulate the `shell` provider on
    Windows --- a command must explicitly invoke the shell:

        exec {'echo foo':
          command => 'cmd.exe /c echo "foo"',
        }

    If no extension is specified for a command, Windows will use the `PATHEXT`
    environment variable to locate the executable.

    **Note on PowerShell scripts:** PowerShell's default `restricted`
    execution policy doesn't allow it to run saved scripts. To run PowerShell
    scripts, specify the `remotesigned` execution policy as part of the
    command:

        exec { 'test':
          path    => 'C:/Windows/System32/WindowsPowerShell/v1.0',
          command => 'powershell -executionpolicy remotesigned -file C:/test.ps1',
        }

  EOT

  # Verify that we have the executable
  def checkexe(command)
    exe = extractexe(command)

    if absolute_path?(exe)
      if !Puppet::FileSystem.exist?(exe)
        raise ArgumentError, "Could not find command '#{exe}'"
      elsif !File.file?(exe)
        raise ArgumentError, "'#{exe}' is a #{File.ftype(exe)}, not a file"
      end
      return
    end

    if resource[:path]
      Puppet::Util.withenv( {'PATH' => resource[:path].join(File::PATH_SEPARATOR)}, :windows) do
        return if which(exe)
      end
    end

    raise ArgumentError, "Could not find command '#{exe}'"
  end
end
