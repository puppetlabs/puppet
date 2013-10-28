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
    packages.each do |name,pkg|
      if pkg.provider.get(:ensure) == :present and pkg.should(:ensure) == :latest
        # without this hack, latest is invoked up to two times, but no install/update comes after that
        # it also mangles the messages shown for present->latest transition
        pkg.provider.set( { :ensure => :latest } )
      end
    end
    pkgin("-y", :update)
  end

  def self.instances
    pkgin(:list).split("\n").map do |package|
      new(parse_pkgin_line(package).merge(:ensure => :present))
    end
  end

  def query
    packages = parse_pkgsearch_line

    if not packages
      if @resource[:ensure] == :absent
        notice "declared as absent but unavailable #{@resource.file}:#{resource.line}"
        return false
      else
        @resource.fail "No candidate to be installed"
      end
    end

    packages.first.merge( :ensure => :absent )
  end

  def parse_pkgsearch_line
    packages = pkgin(:search, resource[:name]).split("\n")

    return nil if packages.length == 1

    # Remove the last three lines of help text.
    packages.slice!(-4, 4)

    pkglist = packages.map{ |line| self.class.parse_pkgin_line(line) }
    pkglist.select{ |package| resource[:name] == package[:name] }
  end

  def install
    pkgin("-y", :install, resource[:name])
  end

  def uninstall
    pkgin("-y", :remove, resource[:name])
  end

  def latest
    package = parse_pkgsearch_line.detect{ |package| package[:status] == '<' }
    @property_hash[:ensure] = :present
    if not package
      set( { :abort => true } )
      return nil
    end
    notice  "Upgrading #{package[:name]} to #{package[:version]}"
    return package[:version]
  end

  def update
    unless @property_hash[:abort]
      install
    end
  end

end
