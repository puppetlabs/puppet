# HP-UX packaging.

require 'puppet/provider/package'

Puppet::Type.type(:package).provide :hpux, :parent => Puppet::Provider::Package do

  desc "HP-UX's packaging system."

  commands :swinstall => "/usr/sbin/swinstall",
    :swlist => "/usr/sbin/swlist",
    :swremove => "/usr/sbin/swremove"

  confine :operatingsystem => "hp-ux"

  defaultfor :operatingsystem => "hp-ux"

  def self.instances
    # TODO:  This is very hard on HP-UX!
    []
  end

  # source and name are required
  def install
    raise ArgumentError, _("source must be provided to install HP-UX packages") unless resource[:source]
    args = standard_args + ["-s", resource[:source], resource[:name]]
    swinstall(*args)
  end

  def query
    swlist resource[:name]
    {:ensure => :present}
  rescue
    {:ensure => :absent}
  end

  def uninstall
    args = standard_args + [resource[:name]]
    swremove(*args)
  end

  def standard_args
    ["-x", "mount_all_filesystems=false"]
  end
end
