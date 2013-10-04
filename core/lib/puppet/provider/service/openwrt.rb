Puppet::Type.type(:service).provide :openwrt, :parent => :init, :source => :init do
  desc <<-EOT
    Support for OpenWrt flavored init scripts.

    Uses /etc/init.d/service_name enable, disable, and enabled.

  EOT

  defaultfor :operatingsystem => :openwrt
  confine :operatingsystem => :openwrt

  has_feature :enableable

  def self.defpath
    ["/etc/init.d"]
  end

  def enable
    system(self.initscript, 'enable')
  end

  def disable
    system(self.initscript, 'disable')
  end

  def enabled?
    # We can't define the "command" for the init script, so we call system?
    if system(self.initscript, 'enabled') then return :true else return :false end
  end

  # Purposely leave blank so we fail back to ps based status detection
  # As OpenWrt init script do not have status commands
  def statuscmd
  end

end
