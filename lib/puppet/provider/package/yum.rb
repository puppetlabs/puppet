require 'puppet/util/package'

Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  desc "Support via `yum`.

  Using this provider's `uninstallable` feature will not remove dependent packages. To
  remove dependent packages with this provider use the `purgeable` feature, but note this
  feature is destructive and should be used with the utmost care."

  has_feature :versionable

  commands :yum => "yum", :rpm => "rpm", :python => "python"

  self::YUMHELPER = File::join(File::dirname(__FILE__), "yumhelper.py")

  attr_accessor :latest_info

  if command('rpm')
    confine :true => begin
      rpm('--version')
      rescue Puppet::ExecutionFailure
        false
      else
        true
      end
  end

  defaultfor :operatingsystem => [:fedora, :centos, :redhat]

  def self.prefetch(packages)
    raise Puppet::Error, "The yum provider can only be used as root" if Process.euid != 0
    super
    return unless packages.detect { |name, package| package.should(:ensure) == :latest }

    # repo_permutations is list of all permutations of enabled and disabled repositories
    repo_permutations = [ { "enablerepo" => [], "disablerepo" => [] } ]
    packages.each_value do |package|
      if package[:enablerepo].is_a? Array
        enablerepo = package[:enablerepo]
      else
        enablerepo = [package[:enablerepo]]
      end
      if package[:disablerepo].is_a? Array
        disablerepo = package[:disablerepo]
      else
        disablerepo = [package[:disablerepo]]
      end
      repos = { "enablerepo" => enablerepo.sort, "disablerepo" =>  disablerepo.sort}
      unless repo_permutations.include?(repos)
        repo_permutations << repos
      end
    end

    updates = {}

    # run yumhelper for each combination of repositories
    repo_permutations.each do |repos|
      arguments = []
      unless repos["enablerepo"].empty?
        arguments += ["-e", repos["enablerepo"].join(",")]
      end
      unless repos["disablerepo"].empty?
        arguments += ["-d", repos["disablerepo"].join(",")]
      end
      # collect our 'latest' info
      python(self::YUMHELPER, *arguments).each_line do |l|
        l.chomp!
        next if l.empty?
        if l[0,4] == "_pkg"
          hash = nevra_to_hash(l[5..-1])
          # include info on which set of repos this update is from
          ["#{hash[:name]}.#{repos}", "#{hash[:name]}.#{hash[:arch]}.#{repos}"].each  do |n|
            updates[n] ||= []
            updates[n] << hash
          end
        end
      end
    end

    # Add our 'latest' info to the providers.
    packages.each do |name, package|
      if package[:enablerepo].is_a? Array
        enablerepo = package[:enablerepo]
      else
        enablerepo = [package[:enablerepo]]
      end
      if package[:disablerepo].is_a? Array
        disablerepo = package[:disablerepo]
      else
        disablerepo = [package[:disablerepo]]
      end
      repos = { "enablerepo" => enablerepo.sort, "disablerepo" =>  disablerepo.sort}
      if info = updates["#{package[:name]}.#{repos}"]
        package.provider.latest_info = info[0]
      end
    end
  end

  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]
    operation = :install

    if @resource[:enablerepo].is_a? Array
      enablerepo = @resource[:enablerepo]
    else
      enablerepo = [@resource[:enablerepo]]
    end
    if @resource[:disablerepo].is_a? Array
      disablerepo = @resource[:disablerepo]
    else
      disablerepo = [@resource[:disablerepo]]
    end

    case should
    when true, false, Symbol
      # pass
      should = nil
    else
      # Add the package version
      wanted += "-#{should}"
      is = self.query
      if is && Puppet::Util::Package.versioncmp(should, is[:ensure]) < 0
        self.debug "Downgrading package #{@resource[:name]} from version #{is[:ensure]} to #{should}"
        operation = :downgrade
      end
    end

    arguments = [ "-d", "0", "-e", "0", "-y" ]
    unless @resource[:disablerepo].empty?
      arguments <<  "--disablerepo=#{disablerepo.join(',')}"
    end
    unless @resource[:enablerepo].empty?
      arguments <<  "--enablerepo=#{enablerepo.join(',')}"
    end
    arguments += [ operation , wanted ]
    yum *arguments

    is = self.query
    raise Puppet::Error, "Could not find package #{self.name}" unless is

    # FIXME: Should we raise an exception even if should == :latest
    # and yum updated us to a version other than @param_hash[:ensure] ?
    raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:ensure]} instead" if should && should != is[:ensure]
  end

  # What's the latest package version available?
  def latest
    upd = latest_info
    unless upd.nil?
      # FIXME: there could be more than one update for a package
      # because of multiarch
      return "#{upd[:epoch]}:#{upd[:version]}-#{upd[:release]}"
    else
      # Yum didn't find updates, pretend the current
      # version is the latest
      raise Puppet::DevError, "Tried to get latest on a missing package" if properties[:ensure] == :absent
      return properties[:ensure]
    end
  end

  def update
    # Install in yum can be used for update, too
    self.install
  end

  def purge
    yum "-y", :erase, @resource[:name]
  end
end
