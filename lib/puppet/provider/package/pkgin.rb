require "puppet/provider/package"

Puppet::Type.type(:package).provide :pkgin, :parent => Puppet::Provider::Package do
  desc "Package management using pkgin, a binary package manager for pkgsrc."

  commands :pkgin => "pkgin"

  defaultfor :operatingsystem => :dragonfly

  has_feature :installable, :uninstallable, :upgradeable

  def self.parse_pkgin_line(package, force_status=nil)

    # e.g.
    #   vim-7.2.446 =        Vim editor (vi clone) without GUI
    match, name, version, status = *package.match(/(\S+)-(\S+)(?: (=|>|<))?\s+.+$/)
    if match
      ensure_status = if force_status
        force_status
      elsif status
        :present
      else
        :absent
      end

      {
        :name     => name,
        :ensure   => ensure_status,
        :provider => :pkgin
      }
    end
  end

  def self.instances
    pkgin(:list).split("\n").map do |package|
      new(parse_pkgin_line(package, :present))
    end
  end

  def query
    packages = pkgin(:search, resource[:name]).split("\n")

    # Remove the last three lines of help text.
    packages.slice!(-3, 3)

    matching_package = nil
    packages.detect do |package|
      properties = self.class.parse_pkgin_line(package)
      matching_package = properties if properties && resource[:name] == properties[:name]
    end

    matching_package
  end

  def install
    pkgin("-y", :install, resource[:name])
  end

  def uninstall
    pkgin("-y", :remove, resource[:name])
  end

  def latest
    # -f seems required when repositories.conf changes
    pkgin("-yf", :update)
    package = self.query
    if package[:status] == '<'
      notice  "Upgrading #{package[:name]} to #{package[:version]}"
      pkgin("-y", :install, package[:name])
    else
      true
    end
  end

end
