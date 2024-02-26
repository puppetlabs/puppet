# frozen_string_literal: true

require_relative '../../../puppet/provider/package'

Puppet::Type.type(:package).provide :pkgng, :parent => Puppet::Provider::Package do
  desc "A PkgNG provider for FreeBSD and DragonFly."

  commands :pkg => "/usr/local/sbin/pkg"

  confine 'os.name' => [:freebsd, :dragonfly]

  defaultfor 'os.name' => [:freebsd, :dragonfly]

  has_feature :versionable
  has_feature :upgradeable
  has_feature :install_options

  def self.get_query
    pkg(['query', '-a', '%n %v %o'])
  end

  def self.get_resource_info(name)
    pkg(['query', '%n %v %o', name])
  end

  def self.cached_version_list
    # rubocop:disable Naming/MemoizedInstanceVariableName
    @version_list ||= get_version_list
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end

  def self.get_version_list
    @version_list = pkg(['version', '-voRL='])
  end

  def self.get_latest_version(origin)
    latest_version = cached_version_list.lines.find { |l| l =~ /^#{origin} / }
    if latest_version
      _name, compare, status = latest_version.chomp.split(' ', 3)
      if ['!', '?'].include?(compare)
        return nil
      end

      latest_version = status.split(' ').last.split(')').first
      return latest_version
    end
    nil
  end

  def self.parse_pkg_query_line(line)
    name, version, origin = line.chomp.split(' ', 3)
    latest_version = get_latest_version(origin) || version

    {
      :ensure => version,
      :name => name,
      :provider => self.name,
      :origin => origin,
      :version => version,
      :latest => latest_version
    }
  end

  def self.instances
    packages = []
    begin
      info = self.get_query
      get_version_list

      unless info
        return packages
      end

      info.lines.each do |line|
        hash = parse_pkg_query_line(line)
        packages << new(hash)
      end

      return packages
    rescue Puppet::ExecutionFailure
      return []
    end
  end

  def self.prefetch(resources)
    packages = instances
    resources.each_key do |name|
      provider = packages.find { |p| p.name == name or p.origin == name }
      if provider
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

    if !source # install using default repo logic
      args = ['install', '-qy']
    elsif source.scheme == 'urn' # install from repo named in URN
      tag = repo_tag_from_urn(source.to_s)
      args = ['install', '-qy', '-r', tag]
    else # add package located at URL
      args = ['add', '-q']
      installname = source.to_s
    end
    args += install_options if @resource[:install_options]
    args << installname

    pkg(args)
  end

  def uninstall
    pkg(['remove', '-qy', resource[:name]])
  end

  def query
    begin
      output = self.class.get_resource_info(resource[:name])
    rescue Puppet::ExecutionFailure
      return nil
    end

    self.class.parse_pkg_query_line(output)
  end

  def version
    @property_hash[:version]
  end

  def version=
    pkg(['install', '-qfy', "#{resource[:name]}-#{resource[:version]}"])
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

  def install_options
    join_options(@resource[:install_options])
  end
end
