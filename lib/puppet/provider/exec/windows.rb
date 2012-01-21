require 'puppet/provider/exec'

Puppet::Type.type(:exec).provide :windows, :parent => Puppet::Provider::Exec do
  include Puppet::Util::Execution

  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  desc "Execute external binaries directly, on Windows systems.
This does not pass through a shell, or perform any interpolation, but
only directly calls the command with the arguments given."

  # Verify that we have the executable
  def checkexe(command)
    exe = extractexe(command)

    if absolute_path?(exe)
      if !File.exists?(exe)
        raise ArgumentError, "Could not find command '#{exe}'"
      elsif !File.file?(exe)
        raise ArgumentError, "'#{exe}' is a #{File.ftype(exe)}, not a file"
      end
      return
    end

    if resource[:path]
      withenv :PATH => resource[:path].join(File::PATH_SEPARATOR) do
        return if which(exe)
      end
    end

    raise ArgumentError, "Could not find command '#{exe}'"
  end
end
