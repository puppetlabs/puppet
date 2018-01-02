require 'puppet/provider/exec'

Puppet::Type.type(:exec).provide :posix, :parent => Puppet::Provider::Exec do
  has_feature :umask
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
      if !Puppet::FileSystem.exist?(exe)
        raise ArgumentError, _("Could not find command '%{exe}'") % { exe: exe }
      elsif !File.file?(exe)
        raise ArgumentError, _("'%{exe}' is a %{klass}, not a file") % { exe: exe, klass: File.ftype(exe) }
      elsif !File.executable?(exe)
        raise ArgumentError, _("'%{exe}' is not executable") % { exe: exe }
      end
      return
    end

    if resource[:path]
      Puppet::Util.withenv :PATH => resource[:path].join(File::PATH_SEPARATOR) do
        return if which(exe)
      end
    end

    # 'which' will only return the command if it's executable, so we can't
    # distinguish not found from not executable
    raise ArgumentError, _("Could not find command '%{exe}'") % { exe: exe }
  end

  def run(command, check = false)
    if resource[:umask]
      Puppet::Util::withumask(resource[:umask]) { super(command, check) }
    else
      super(command, check)
    end
  end
end
