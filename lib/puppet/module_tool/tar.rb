require 'puppet/module_tool'
require 'puppet/util'

module Puppet::ModuleTool::Tar
  require 'puppet/module_tool/tar/gnu'
  require 'puppet/module_tool/tar/mini'

  def self.instance
    if Puppet.features.minitar? && Puppet.features.zlib?
      Mini.new
    elsif Puppet::Util.which('tar') && ! Puppet::Util::Platform.windows?
      Gnu.new
    else
      #TRANSLATORS "tar" is a program name and should not be translated
      raise RuntimeError, _('No suitable tar implementation found')
    end
  end
end
