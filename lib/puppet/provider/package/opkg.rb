require 'puppet/provider/package'

Puppet::Type.type(:package).provide :opkg, :source => :opkg, :parent => Puppet::Provider::Package do
  desc "Opkg packaging support. Common on OpenWrt and OpenEmbedded platforms"

  commands :opkg => "opkg"

  confine     :operatingsystem => :openwrt
  defaultfor  :operatingsystem => :openwrt

  def self.instances
    packages = []
    execpipe("#{command(:opkg)} list-installed") do |process|
      regex = %r{^(\S+) - (\S+)}
      fields = [:name, :ensure]
      hash = {}

      process.each_line { |line|
        if match = regex.match(line)
          fields.zip(match.captures) { |field,value| hash[field] = value }
          hash[:provider] = self.name
          packages << new(hash)
          hash = {}
        else
          warning(_("Failed to match line %{line}") % { line: line })
        end
      }
    end
    packages
  rescue Puppet::ExecutionFailure
    return nil
  end

  def latest
    output = opkg( "list", @resource[:name])
    matches = /^(\S+) - (\S+)/.match(output).captures
    matches[1]
  end

  def install
    # OpenWrt package lists are ephemeral, make sure we have at least
    # some entries in the list directory for opkg to use
    opkg('update') if package_lists.size <= 2

    if @resource[:source]
      opkg( '--force-overwrite', 'install', @resource[:source] )
    else
      opkg( '--force-overwrite', 'install', @resource[:name] )
    end
  end

  def uninstall
    opkg( 'remove', @resource[:name] )
  end

  def update
    self.install
  end

  def query
    # list out our specific package
    output = opkg( 'list-installed', @resource[:name] )
    if output =~ /^(\S+) - (\S+)/
      return { :ensure => $2 }
    end
    nil
  rescue Puppet::ExecutionFailure
    return {
      :ensure => :purged,
      :status => 'missing',
      :name => @resource[:name],
      :error => 'ok',
    }
  end

  private

  def package_lists
    Dir.entries('/var/opkg-lists/')
  end
end
