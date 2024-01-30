# frozen_string_literal: true

require_relative '../../../puppet/provider/exec'

Puppet::Type.type(:exec).provide :posix, :parent => Puppet::Provider::Exec do
  has_feature :umask
  confine :feature => :posix
  defaultfor :feature => :posix

  desc <<-EOT
    Executes external binaries by invoking Ruby's `Kernel.exec`.
    When the command is a string, it will be executed directly,
    without a shell, if it follows these rules:
     - no meta characters
     - no shell reserved word and no special built-in

    When the command is an Array of Strings, passed as `[cmdname, arg1, ...]`
    it will be executed directly(the first element is taken as a command name
    and the rest are passed as parameters to command with no shell expansion)
    This is a safer and more predictable way to execute most commands,
    but prevents the use of globbing and shell built-ins (including control
    logic like "for" and "if" statements).

    If the use of globbing and shell built-ins is desired, please check
    the `shell` provider

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
      Puppet::Util.withumask(resource[:umask]) { super(command, check) }
    else
      super(command, check)
    end
  end
end
