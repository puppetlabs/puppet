require 'puppet/provider/package'

Puppet::Type.type(:package).provide :pkgng, :parent => Puppet::Provider::Package do
  desc "A PkgNG provider for FreeBSD and DragonFly."

  commands :pkg => "/usr/local/sbin/pkg"

  confine :operatingsystem => [:freebsd, :dragonfly]

  defaultfor :operatingsystem => [:freebsd, :dragonfly]

  has_feature :versionable
  has_feature :upgradeable

  def self.get_query
    pkg(['query', '-a', '%n %v %o'])
  end

  def self.get_version_list
    pkg(['version', '-voRL='])
  end

  def self.get_latest_version(origin, version_list)
    if latest_version = version_list.lines.find { |l| l =~ /^#{origin} / }
      latest_version = latest_version.split(' ').last.split(')').first
      return latest_version
    end
    nil
  end

  def self.instances
    packages = []
    begin
      info = self.get_query
      version_list = self.get_version_list

      unless info
        return packages
      end

      info.lines.each do |line|

        name, version, origin = line.chomp.split(" ", 3)
        latest_version  = get_latest_version(origin, version_list) || version

        pkg = {
          :ensure   => version,
          :name     => name,
          :provider => self.name,
          :origin   => origin,
          :version  => version,
          :latest   => latest_version
        }
        packages << new(pkg)
      end

      return packages
    rescue Puppet::ExecutionFailure
      return []
    end
  end

  def self.prefetch(resources)
    packages = instances
    resources.each_key do |name|
      if provider = packages.find{|p| p.name == name or p.origin == name }
        resources[name].provider = provider
      end
    end
  end

  def repo_tag_from_urn(urn)
    # extract repo tag from URN: urn:freebsd:repo:<tag>
    match = /^urn:freebsd:repo:(.+)$/.match(urn)
    raise ArgumentError urn.inspect unless match
    match[1]
  end

  def install
    source = resource[:source]
    source = URI(source) unless source.nil?

    # Ensure we handle the version
    case resource[:ensure]
    when true, false, Symbol
      installname = resource[:name]
    else
      # If resource[:name] is actually an origin (e.g. 'www/curl' instead of
      # just 'curl'), drop the category prefix. pkgng doesn't support version
      # pinning with the origin syntax (pkg install curl-1.2.3 is valid, but
      # pkg install www/curl-1.2.3 is not).
      if resource[:name] =~ /\//
        installname = resource[:name].split('/')[1] + '-' + resource[:ensure]
      else
        installname = resource[:name] + '-' + resource[:ensure]
      end
    end

    if not source # install using default repo logic
      args = ['install', '-qy', installname]
    elsif source.scheme == 'urn' # install from repo named in URN
      tag = repo_tag_from_urn(source.to_s)
      args = ['install', '-qy', '-r', tag, installname]
    else # add package located at URL
      args = ['add', '-q', source.to_s]
    end

    pkg(args)
  end

  def uninstall
    pkg(['remove', '-qy', resource[:name]])
  end

  def query
    if @property_hash[:ensure] == nil
      return nil
    else
      version = @property_hash[:version]
      return { :version => version }
    end
  end

  def version
    @property_hash[:version]
  end

  # Upgrade to the latest version
  def update
    install
  end

  # Return the latest version of the package
  def latest
    debug "returning the latest #{@property_hash[:name].inspect} version #{@property_hash[:latest].inspect}"
    @property_hash[:latest]
  end

  def origin
    @property_hash[:origin]
  end

end
