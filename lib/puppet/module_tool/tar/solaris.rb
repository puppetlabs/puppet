class Puppet::ModuleTool::Tar::Solaris < Puppet::ModuleTool::Tar::Gnu
  def unpack(sourcefile, destdir)
    Puppet::Util::Execution.execute("gtar xzf #{sourcefile} -C #{destdir}")
  end
end
