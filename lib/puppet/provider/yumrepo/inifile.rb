require 'puppet/util/inifile'

Puppet::Type.type(:yumrepo).provide(:inifile) do
  desc 'Manage yum repos'

  PROPERTIES = Puppet::Type.type(:yumrepo).validproperties

  def self.instances
    instances = []
    # Iterate over each section of our virtual file.
    virtual_inifile.each_section do |section|
      attributes_hash = {:name => section.name, :ensure => :present, :provider => :yumrepo}
      # We need to build up a attributes hash
      section.entries.each do |key, value|
        key = key.to_sym
        if valid_property?(key)
          # We strip the values here to handle cases where distros set values
          # like enabled = 1 with spaces.
          attributes_hash[key] = value.strip
        end
      end
      instances << new(attributes_hash)
    end
  return instances
  end

  def self.prefetch(resources)
    repos = instances
    resources.keys.each do |name|
      if provider = repos.find { |repo| repo.name == name }
        resources[name].provider = provider
      end
    end
  end

  # Return a list of existing directories that could contain repo files.  Fail if none found.
  def self.reposdir(conf='/etc/yum.conf', dirs=['/etc/yum.repos.d', '/etc/yum/repos.d'])
    reposdir = find_conf_value('reposdir', conf)
    dirs << reposdir if reposdir

    dirs.select! { |dir| Puppet::FileSystem.exist?(dir) }
    if dirs.empty?
      fail("No yum directories were found on the local filesystem")
    else
      return dirs
    end
  end

  # Find configuration values in .conf files and return them
  # if found.
  def self.find_conf_value(value, conf='/etc/yum.conf')
    if File.exists?(conf)
      contents = File.read(conf)
      match = /^#{value}\s*=\s*(.*)/.match(contents)
    end

    return match.captures[0] if match
  end

  # Build a virtual inifile by reading in numerous .repo
  # files into a single virtual file to ease manipulation.
  def self.virtual_inifile
    unless @virtual
      @virtual = Puppet::Util::IniConfig::File.new
      reposdir.each do |dir|
        Dir.glob("#{dir}/*.repo").each do |file|
          @virtual.read(file) if ::File.file?(file)
        end
      end
    end
    return @virtual
  end

  def self.valid_property?(key)
    PROPERTIES.include?(key)
  end

  # Return the named section out of the virtual_inifile.
  def self.section(name)
    result = self.virtual_inifile[name]
    # Create a new section if not found.
    unless result
      reposdir.each do |dir|
        path = ::File.join(dir, "#{name}.repo")
        Puppet.info("create new repo #{name} in file #{path}")
        result = self.virtual_inifile.add_section(name, path)
      end
    end
    result
  end

  # Store all modifications back to disk
  def self.store
    inifile = self.virtual_inifile
    inifile.store

    target_mode = 0644
    inifile.each_file do |file|
      current_mode = Puppet::FileSystem.stat(file).mode & 0777
      unless current_mode == target_mode
        Puppet.info "changing mode of #{file} from %03o to %03o" % [current_mode, target_mode]
        ::File.chmod(target_mode, file)
      end
    end
  end

  def create
    @property_hash[:ensure] = :present

    # We fetch a list of properties from the type, then iterate
    # over them, avoiding ensure.  We're relying on .should to
    # check if the property has been set and should be modified,
    # and if so we set it in the virtual inifile.
    PROPERTIES.each do |property|
      next if property == :ensure
      if value = @resource.should(property)
        section(@resource[:name])[property.to_s] = value
        @property_hash[property] = value
      end
    end
  end

  def destroy
    # Flag file for deletion on flush.
    section(@resource[:name]).destroy=(true)

    @property_hash.clear
  end

  def flush
    self.class.store
  end

  def section(name)
    self.class.section(name)
  end

  # Create all of our setters.
  mk_resource_methods
  PROPERTIES.each do |property|
    # Exclude ensure, as we don't need to create an ensure=
    next if property == :ensure
    # Builds the property= method.
    define_method("#{property.to_s}=") do |value|
      section(@property_hash[:name])[property.to_s] = value
      @property_hash[property] = value
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

end
