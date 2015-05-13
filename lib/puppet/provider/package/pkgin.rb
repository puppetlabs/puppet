require "puppet/provider/package"

Puppet::Type.type(:package).provide :pkgin, :parent => Puppet::Provider::Package do
  desc "Package management using pkgin, a binary package manager for pkgsrc."

  commands :pkgin => "pkgin"

  defaultfor :operatingsystem => [ :dragonfly , :smartos, :netbsd ]

  has_feature :installable, :uninstallable, :upgradeable, :versionable

  def self.parse_pkgin_line(package)

    # e.g.
    #   vim-7.2.446;Vim editor (vi clone) without GUI
    match, name, version, status = *package.match(/([^\s;]+)-([^\s;]+)[;\s](=|>|<)?.+$/)
    if match
      {
        :name     => name,
        :status   => status,
        :ensure   => version
      }
    end
  end

  def self.prefetch(packages)
    super
    # Withouth -f, no fresh pkg_summary files are downloaded
    pkgin("-yf", :update)
  end

  def self.instances
    pkgin(:list).split("\n").map do |package|
      new(parse_pkgin_line(package))
    end
  end

  def query
    packages = parse_pkgsearch_line

    if packages.empty?
      if @resource[:ensure] == :absent
        notice "declared as absent but unavailable #{@resource.file}:#{resource.line}"
        return false
      else
        @resource.fail "No candidate to be installed"
      end
    end

    packages.first.update( :ensure => :absent )
  end

  def parse_pkgsearch_line
    packages = pkgin(:search, resource[:name]).split("\n")

    return [] if packages.length == 1

    # Remove the last three lines of help text.
    packages.slice!(-4, 4)

    pkglist = packages.map{ |line| self.class.parse_pkgin_line(line) }
    pkglist.select{ |package| resource[:name] == package[:name] }
  end

  def install
    if String === @resource[:ensure]
      pkgin("-y", :install, "#{resource[:name]}-#{resource[:ensure]}")
    else
      pkgin("-y", :install, resource[:name])
    end
  end

  def uninstall
    pkgin("-y", :remove, resource[:name])
  end

  def latest
    package = parse_pkgsearch_line.detect{ |p| p[:status] == '<' }
    return properties[:ensure] if not package
    return package[:ensure]
  end

  def update
    pkgin("-y", :install, resource[:name])
  end

end
