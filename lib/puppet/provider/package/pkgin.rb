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
        :status   => status,
        :version  => version,
        :provider => :pkgin
      }
    end
  end

  def self.prefetch(packages)
    super
    # -f seems required when repositories.conf changes
    pkgin("-yf", :update)
  end

  def self.instances
    pkgin(:list).split("\n").map do |package|
      new(parse_pkgin_line(package, :present))
    end
  end

  def query_upgrades
    packages = pkgin(:search, resource[:name]).split("\n")

    # Remove the last three lines of help text.
    packages.slice!(-3, 3)

    pkglist = packages.map{ |line| self.class.parse_pkgin_line(line) }
    pkglist.detect{ |package| resource[:name] == package[:name] and [ '<' , nil ].index( package[:status] ) }
  end

  def install
    pkgin("-y", :install, resource[:name])
  end

  def uninstall
    pkgin("-y", :remove, resource[:name])
  end

  def latest
    package = self.query_upgrades
    return nil if not package
    if package[:status] == '<' or package[:status] == nil
      notice  "Upgrading #{package[:name]} to #{package[:version]}"
      pkgin("-y", :install, package[:name])
      package[:ensure] = :present if package[:ensure] == :absent
    else
      true
    end
  end

end
