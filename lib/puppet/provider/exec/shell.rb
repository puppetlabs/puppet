Puppet::Type.type(:exec).provide :shell, :parent => :posix do
  include Puppet::Util::Execution

  confine :feature => :posix

  desc "Execute external binaries directly, on POSIX systems.
passing through a shell so that shell built ins are available."

  def run(command, check = false)
    command = %Q{/bin/sh -c "#{command.gsub(/"/,'\"')}"}
    super(command, check)
  end

  def validatecmd(command)
    true
  end
end
