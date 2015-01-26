require 'shellwords'

class Puppet::ModuleTool::Tar::Gnu
  def unpack(sourcefile, destdir, owner)
    sourcefile = File.expand_path(sourcefile)
    destdir = File.expand_path(destdir)

    Dir.chdir(destdir) do
      Puppet::Util::Execution.execute("gzip -dc #{Shellwords.shellescape(sourcefile)} | tar xof -")
      Puppet::Util::Execution.execute("find . -type d -exec chmod 755 {} +")
      Puppet::Util::Execution.execute("find . -type f -exec chmod u+rw,g+r,a-st {} +")
      Puppet::Util::Execution.execute("chown -R #{owner} .")
    end
  end

  def pack(sourcedir, destfile)
    Puppet::Util::Execution.execute("tar cf - #{sourcedir} | gzip -c > #{File.basename(destfile)}")
  end
end
