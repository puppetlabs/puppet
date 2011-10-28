require 'puppet/provider/package'
require 'puppet/util/package'

Puppet::Type.type(:package).provide :nim, :parent => :aix, :source => :aix do
  desc "Installation from NIM LPP source."

  # The commands we are using on an AIX box are installed standard
  # (except nimclient) nimclient needs the bos.sysmgt.nim.client fileset.
  commands    :nimclient => "/usr/sbin/nimclient"

  # If NIM has not been configured, /etc/niminfo will not be present.
  # However, we have no way of knowing if the NIM server is not configured
  # properly.
  confine  :exists => "/etc/niminfo"

  has_feature :versionable

  attr_accessor :latest_info

  def self.srclistcmd(source)
    [ command(:nimclient), "-o", "showres", "-a", "installp_flags=L", "-a", "resource=#{source}" ]
  end

  def install(useversion = true)
    unless source = @resource[:source]
      self.fail "An LPP source location is required in 'source'"
    end

    pkg = @resource[:name]

    pkg << " " << @resource.should(:ensure) if (! @resource.should(:ensure).is_a? Symbol) and useversion

    nimclient "-o", "cust", "-a", "installp_flags=acgwXY", "-a", "lpp_source=#{source}", "-a", "filesets='#{pkg}'"
  end
end
