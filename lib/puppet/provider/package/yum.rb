require 'puppet/util/package'

Puppet::Type.type(:package).provide :yum, :parent => :rpm, :source => :rpm do
  desc "Support via `yum`."

  has_feature :versionable

  commands :yum => "yum", :rpm => "rpm", :python => "python"

  YUMHELPER = File::join(File::dirname(__FILE__), "yumhelper.py")
  YUM_INSTALLONLY = File::join(File::dirname(__FILE__), "yum_installonly.py")
  NEVRAFORMAT = "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}"
  NEVRA_FIELDS = [:name, :epoch, :version, :release, :arch]

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

    # collect our 'latest' info
    updates = {}
    python(YUMHELPER).each_line do |l|
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
        package.provider.latest_info = info
      end
    end
  end

  def installonly_pkg?
    return false if @resource.should(:ensure) == :latest
    python("#{YUM_INSTALLONLY}","#{@resource[:name]}").each_line do |line|
      line.chomp!
      next if line.empty?
      # yum_installonly does: print "_pkg %s %s %s %s %s" % ( pkg.name, pkg.version, pkg.release, pkg.arch, my.tsInfo._allowedMultipleInstalls( pkg ) )
      if (line[0,4] == "_pkg" && (line.split[2] == @resource.should(:ensure) || "#{line.split[2]}-#{line.split[3]}" == @resource.should(:ensure)) && line.split.last == "True")
        return true
      end
    end
    return false
  end

  def current_versions
    # Yes, we could have many due to installonly_pkg's and multilibs
    cmd = ["-q", @resource[:name], "--nosignature", "--nodigest", "--qf", "#{NEVRAFORMAT}\n"]
    begin
      output = rpm(*cmd)
    rescue Puppet::ExecutionFailure
      return nil
    end
    return nil if output == nil
    versions=[]
    output.each_line do |line|
      line.chomp!
      next if line.empty?
      hash={}
      NEVRA_FIELDS.zip(line.split) { |f, v| hash[f] = v }
      hash[:provider] = self.name
      hash[:ensure] = "#{hash[:version]}-#{hash[:release]}"
      versions << {:name => self.name,:version => hash[:ensure]} unless versions.member?(hash)
    end
    versions
  end

  def latest_installed_version(installed_versions=self.current_versions)
    return nil if self.query == nil
    latest_version=self.query[:ensure]
    installed_versions.each do |v|
      next unless v[:version]
      if ((Puppet::Util::Package.versioncmp(latest_version, v[:version]) < 0))
        latest_version=v[:version]
      end
    end
    latest_version
  end

  def install
    should = @resource.should(:ensure)
    self.debug "Ensuring => #{should}"
    wanted = @resource[:name]
    operation = :install
    installonly_pkg = self.installonly_pkg?
    installed_versions = self.current_versions
    latest_version = self.latest_installed_version(installed_versions)

    case should
    when true, false, Symbol
      # pass
      should = nil
    else
      # Add the package version
      wanted += "-#{should}"
      if (latest_version != nil && installed_versions != nil)
        if installed_versions.member?({:name => @resource[:name],:version => should})
          return
        else
          if ((Puppet::Util::Package.versioncmp(should, latest_version) < 0) && !(installonly_pkg))
            self.debug "Downgrading package #{@resource[:name]} from version #{latest_version} to #{should}"
            operation = :downgrade
          end
        end
      end
    end

    output = yum "-d", "0", "-e", "0", "-y", operation, wanted

    installed_versions = self.current_versions
    latest_version = self.latest_installed_version(installed_versions)
    raise Puppet::Error, "Could not find package #{self.name}" unless installed_versions
    if (should && installed_versions.member?({:name => @resource[:name],:version => should})) || (['present','installed','latest'].member?(@resource[:ensure].to_s))
      # We have what we came for, good to go
      return
    else
      # We don't have it, bummer.
      raise Puppet::Error, "Failed to update to version #{should}, got version #{latest_version} instead"
    end
  end

  # What's the latest package version available?
  def latest
    self.current_versions
    upd = latest_info
    unless upd.nil?
      return upd.collect {|u| "#{u[:epoch]} #{u[:version]}-#{u[:release]}"}
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