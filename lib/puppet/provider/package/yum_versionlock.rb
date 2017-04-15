require 'puppet/util/package'

Puppet::Type.type(:package).provide :yum_versionlock, :parent => :yum, :source => :rpm do
  desc "Support via `yum` with the feature holdable.

  This provider requires yum-plugin-versionlock to be installed.
  
  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care."

  has_feature :holdable

  defaultfor :operatingsystem => [:fedora, :centos, :redhat]
  confine :operatingsystem => [:fedora, :centos, :redhat]
  confine :exists => '/usr/lib/yum-plugins/versionlock.py'

  commands :yum => "yum"
  commands :rpm => "rpm"

  attr_accessor :latest_info

  def hold
    self.install

    lockstring = rpm '-q', '--qf', '%{EPOCHNUM}:%{NAME}-%{VERSION}-%{RELEASE}.*', @resource[:name]
    locklist = yum 'versionlock', 'list', '-q'

    if locklist.include? lockstring
      Puppet.debug("yum_versionlock already added for " + @resource[:name])
    else
      Puppet.debug("yum_versionlock adding " + @resource[:name])
      yum 'versionlock', 'add',  '-q', @resource[:name]
    end
  end

  def unhold
    lockstring = rpm '-q', '--qf', '%{EPOCHNUM}:%{NAME}-%{VERSION}-%{RELEASE}.*', @resource[:name]
    yum 'versionlock', 'delete', '-q', lockstring
  end
end
