class Puppet::ModuleTool::Tar::Solaris < Puppet::ModuleTool::Tar::Gnu
  def initialize
    super("gtar")
  end
end
