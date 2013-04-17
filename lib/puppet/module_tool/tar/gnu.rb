class Puppet::ModuleTool::Tar::Gnu
  def unpack(sourcefile, destdir)
    Puppet::Util::Execution.execute("tar xzf #{sourcefile} -C #{destdir}")
  end

  def pack(sourcedir, destfile)
    Puppet::Util::Execution.execute("tar cf - #{sourcedir} | gzip -c > #{destfile}")
  end
end
