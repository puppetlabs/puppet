require 'puppet/provider/package'

Puppet::Type.type(:package).provide :pkgng, :parent => Puppet::Provider::Package do
  desc "A PKGng provider for FreeBSD."

  commands :pkg => "/usr/local/sbin/pkg"

  confine :operatingsystem => :freebsd

  def self.instances
    inst = Array.new
    package = Hash.new
    cmd = ['info', '-a']
    pkg_list = pkg(*cmd).to_a

    pkg_list.each do |pkgs|
      pkgs = pkgs.split
      pkg_info = pkgs[0].split('-')
      pkg = {
        :ensure   => pkg_info.pop,
        :name     => pkg_info.join('-'),
        :provider => self.name
      }
      inst << new(pkg)
    end
    inst
  end

  def install
    should = @resource.should(:ensure)
    cmd = ['install', '-qyL', @resource[:name]]
    pkg(*cmd)
  end

  def uninstall
    cmd = ['remove', @resource[:name]]
    pkg(*cmd)
  end

  def query
    hash = Hash.new
    #cmd = ["query", "'%v'", @resource[:name]]
    cmd = ["info", "-q", @resource[:name]]
    begin
      hash[:ensure] = pkg(*cmd)
      hash
    rescue
      hash[:ensure] = :purged
      hash
    end
  end

end
