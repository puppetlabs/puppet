module Puppet::ModuleTool::Tar
  require 'puppet/module_tool/tar/gnu'
  require 'puppet/module_tool/tar/solaris'
  require 'puppet/module_tool/tar/mini'

  def self.instance(module_name)
    if Facter.value('osfamily') == 'Solaris' && Puppet::Util.which('gtar') && ! Puppet::Util::Platform.windows?
      Solaris.new
    elsif Puppet::Util.which('tar') && ! Puppet::Util::Platform.windows?
      Gnu.new
    elsif Puppet.features.minitar? && Puppet.features.zlib?
      Mini.new(module_name)
    else
      raise RuntimeError, 'No suitable tar implementation found'
    end
  end
end
