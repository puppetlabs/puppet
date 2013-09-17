Puppet::Type.type(:service).provide :openbsd, :parent => :init do

  desc "Provider for OpenBSD's rc.d daemon control scripts"

  confine :operatingsystem => :openbsd
  defaultfor :operatingsystem => :openbsd

  def self.defpath
    ["/etc/rc.d"]
  end

  def startcmd
    [self.initscript, "-f", :start]
  end

  def restartcmd
    (@resource[:hasrestart] == :true) && [self.initscript, "-f", :restart]
  end

  def statuscmd
    [self.initscript, :check]
  end
end
