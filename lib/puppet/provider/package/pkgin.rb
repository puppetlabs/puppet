require "puppet/provider/package"

Puppet::Type.type(:package).provide :pkgin, :parent => Puppet::Provider::Package do
  desc "Package management using pkgin, a binary package manager for pkgsrc."

  commands :pkgin => "pkgin"

  defaultfor :operatingsystem => [ :dragonfly , :smartos ]


  has_feature :installable, :uninstallable, :upgradeable

  def self.parse_pkgin_line(package)

    # e.g.
    #   vim-7.2.446 =        Vim editor (vi clone) without GUI
    match, name, version, status = *package.match(/(\S+)-(\S+)(?: (=|>|<))?\s+.+$/)
    if match
      {
        :name     => name,
        :status   => status,
        :version  => version
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
      new(parse_pkgin_line(package).merge(:ensure => :present))
    end
  end

  def query_upgrades
    packages = pkgin(:search, resource[:name]).split("\n")

    # Remove the last three lines of help text.
    packages.slice!(-4, 4)

    pkglist = packages.map{ |line| self.class.parse_pkgin_line(line) }
    pkglist.detect{ |package| resource[:name] == package[:name] and [ '<' , nil ].index( package[:status] ) } if pkglist
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
    notice  "Upgrading #{package[:name]} to #{package[:version]}"
    pkgin("-y", :install, package[:name])
    package.update( { :ensure => :present } )
  end

end
