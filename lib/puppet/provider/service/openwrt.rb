# frozen_string_literal: true

Puppet::Type.type(:service).provide :openwrt, :parent => :init, :source => :init do
  desc <<-EOT
    Support for OpenWrt flavored init scripts.

    Uses /etc/init.d/service_name enable, disable, and enabled.

  EOT

  defaultfor 'os.name' => :openwrt
  confine 'os.name' => :openwrt

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
    system(self.initscript, 'enabled') ? (return :true) : (return :false)
  end

  # Purposely leave blank so we fail back to ps based status detection
  # As OpenWrt init script do not have status commands
  def statuscmd
  end
end
