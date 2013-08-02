class Puppet::ModuleTool::Tar::Solaris < Puppet::ModuleTool::Tar::Gnu
  def unpack(sourcefile, destdir, uid)
    Puppet::Util::Execution.execute("gtar xzf #{sourcefile} --no-same-permissions --no-same-owner -C #{destdir}")
    Puppet::Util::Execution.execute("find #{destdir} -type d -exec chmod 755 {} +")
    Puppet::Util::Execution.execute("find #{destdir} -type f -exec chmod 644 {} +")
    Puppet::Util::Execution.execute("chown -R #{uid} #{destdir}")
  end
end
