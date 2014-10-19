require 'puppet/provider/package'

Puppet::Type.type(:package).provide :pkgng, :parent => Puppet::Provider::Package do
  desc "A PkgNG provider for FreeBSD and DragonFly."

  commands :pkg => "/usr/local/sbin/pkg"

  confine :operatingsystem => [:freebsd, :dragonfly]
  confine :pkgng_enabled => :true

  defaultfor :operatingsystem => :freebsd
  defaultfor :pkgng_enabled => :true


  has_feature :versionable
  has_feature :upgradeable

  def self.get_query
    @pkg_query = @pkg_query || pkg(['query', '-a', '%n %v %o'])
    @pkg_query
  end

  def self.get_version_list
    @version_list = @version_list || pkg(['version', '-voRL='])
    @version_list
  end

  def self.get_latest_version(origin)
    if latest_version = self.get_version_list.lines.find { |l| l =~ /^#{origin}/ }
      latest_version = latest_version.split(' ').last.split(')').first
      return latest_version
    end
    nil
  end

  def self.instances
    packages = []
    begin
      info = self.get_query

      unless info
        return packages
      end

      info.lines.each do |line|

        name, version, origin = line.chomp.split(" ", 3)
        latest_version  = get_latest_version(origin) || version

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
      nil
    end
  end

  def self.prefetch(resources)
    packages = instances
    resources.keys.each do |name|
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
    if resource[:ensure] =~ /\./
      installname = resource[:name] + '-' + resource[:ensure]
    else
      installname = resource[:name]
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
    debug @property_hash
    if @property_hash[:ensure] == nil
      return nil
    else
      version = @property_hash[:version]
      return { :version => version }
    end
  end

  def version
    debug @property_hash[:version].inspect
    @property_hash[:version]
  end

  def version=
    pkg(['install', '-qy', "#{resource[:name]}-#{resource[:version]}"])
  end

  def origin
    debug @property_hash[:origin].inspect
    @property_hash[:origin]
  end

  # Upgrade to the latest version
  def update
    debug 'pkgng: update called'
    install
  end

  # Returnthe latest version of the package
  def latest
    debug "returning the latest #{@property_hash[:name].inspect} version #{@property_hash[:latest].inspect}"
    @property_hash[:latest]
  end

end
