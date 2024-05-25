# frozen_string_literal: true

require 'shellwords'

class Puppet::ModuleTool::Tar::Gnu
  def unpack(sourcefile, destdir, owner)
    safe_sourcefile = Shellwords.shellescape(File.expand_path(sourcefile))
    destdir = File.expand_path(destdir)
    safe_destdir = Shellwords.shellescape(destdir)

    Puppet::Util::Execution.execute("gzip -dc #{safe_sourcefile} | tar --extract --no-same-owner --directory #{safe_destdir} --file -")
    Puppet::Util::Execution.execute(['find', destdir, '-type', 'd', '-exec', 'chmod', '755', '{}', '+'])
    Puppet::Util::Execution.execute(['find', destdir, '-type', 'f', '-exec', 'chmod', 'u+rw,g+r,a-st', '{}', '+'])
    Puppet::Util::Execution.execute(['chown', '-R', owner, destdir])
  end

  def pack(sourcedir, destfile)
    safe_sourcedir = Shellwords.shellescape(sourcedir)
    safe_destfile = Shellwords.shellescape(File.basename(destfile))

    Puppet::Util::Execution.execute("tar cf - #{safe_sourcedir} | gzip -c > #{safe_destfile}")
  end
end
