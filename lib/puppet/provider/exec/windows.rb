require 'puppet/provider/exec'

Puppet::Type.type(:exec).provide :windows, :parent => Puppet::Provider::Exec do
  include Puppet::Util::Execution

  confine :feature => :microsoft_windows
  defaultfor :feature => :microsoft_windows

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

    path = resource[:path] || []

    exts = [".exe", ".ps1", ".bat", ".com", ""]
    withenv :PATH => path.join(File::PATH_SEPARATOR) do
      return if exts.any? {|ext| which(exe + ext) }
    end

    raise ArgumentError, "Could not find command '#{exe}'"
  end
end
