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
    return unless packages.detect { |name, package| package.should(:making_sure) == :latest }

    # collect our 'latest' info
    updates = {}
    python(self::YUMHELPER).each_line do |l|
      l.chomp!
      next if l.empty?
      if l[0,4] == "_pkg"
        hash = nevra_to_hash(l[5..-1])
        [hash[:name], "#{hash[:name]}.#{hash[:arch]}"].each  do |n|
          updates[n] ||= []
          updates[n] << hash
        end
      end
    end

    # Add our 'latest' info to the providers.
    packages.each do |name, package|
      if info = updates[package[:name]]
        package.provider.latest_info = info[0]
      end
    end
  end

  def install
    should = @resource.should(:making_sure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]
    operation = :install

    case should
    when true, false, Symbol
      # pass
      should = nil
    else
      # Add the package version
      wanted += "-#{should}"
      is = self.query
      if is && Puppet::Util::Package.versioncmp(should, is[:making_sure]) < 0
        self.debug "Downgrading package #{@resource[:name]} from version #{is[:making_sure]} to #{should}"
        operation = :downgrade
      end
    end

    yum "-d", "0", "-e", "0", "-y", operation, wanted

    is = self.query
    raise Puppet::Error, "Could not find package #{self.name}" unless is

    # FIXME: Should we raise an exception even if should == :latest
    # and yum updated us to a version other than @param_hash[:making_sure] ?
    raise Puppet::Error, "Failed to update to version #{should}, got version #{is[:making_sure]} instead" if should && should != is[:making_sure]
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
      raise Puppet::DevError, "Tried to get latest on a missing package" if properties[:making_sure] == :absent
      return properties[:making_sure]
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
