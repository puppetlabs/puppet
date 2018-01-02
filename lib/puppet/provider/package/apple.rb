require 'puppet/provider/package'

# OS X Packaging sucks.  We can install packages, but that's about it.
Puppet::Type.type(:package).provide :apple, :parent => Puppet::Provider::Package do
  desc "Package management based on OS X's built-in packaging system.  This is
    essentially the simplest and least functional package system in existence --
    it only supports installation; no deletion or upgrades.  The provider will
    automatically add the `.pkg` extension, so leave that off when specifying
    the package name."

  confine :operatingsystem => :darwin
  commands :installer => "/usr/sbin/installer"

  def self.instances
    instance_by_name.collect do |name|
      self.new(
        :name     => name,
        :provider => :apple,
        :ensure   => :installed
      )
    end
  end

  def self.instance_by_name
    Dir.entries("/Library/Receipts").find_all { |f|
      f =~ /\.pkg$/
    }.collect { |f|
      name = f.sub(/\.pkg/, '')
      yield name if block_given?

      name
    }
  end

  def query
    Puppet::FileSystem.exist?("/Library/Receipts/#{@resource[:name]}.pkg") ? {:name => @resource[:name], :ensure => :present} : nil
  end

  def install
    unless source = @resource[:source]
      self.fail _("Mac OS X packages must specify a package source")
    end

    installer "-pkg", source, "-target", "/"
  end
end
