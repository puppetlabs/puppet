require 'puppet/provider/exec'

Puppet::Type.type(:exec).provide :posix, :parent => Puppet::Provider::Exec do
  confine :feature => :posix
  defaultfor :feature => :posix

  desc <<-EOT
    Executes external binaries directly, without passing through a shell or
    performing any interpolation. This is a safer and more predictable way
    to execute most commands, but prevents the use of globbing and shell
    built-ins (including control logic like "for" and "if" statements).
  EOT

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
end
