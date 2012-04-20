Puppet::Type.type(:exec).provide :shell, :parent => :posix do
  include Puppet::Util::Execution

  confine :feature => :posix

  desc <<-EOT
    Passes the provided command through `/bin/sh`; only available on
    POSIX systems. This allows the use of shell globbing and built-ins, and
    does not require that the path to a command be fully-qualified. Although
    this can be more convenient than the `posix` provider, it also means that
    you need to be more careful with escaping; as ever, with great power comes
    etc. etc.

    This provider closely resembles the behavior of the `exec` type
    in Puppet 0.25.x.
  EOT

  def run(command, check = false)
    super(['/bin/sh', '-c', command], check)
  end

  def validatecmd(command)
    true
  end
end
