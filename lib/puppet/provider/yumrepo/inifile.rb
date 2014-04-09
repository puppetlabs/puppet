require 'puppet/util/inifile'

Puppet::Type.type(:yumrepo).provide(:inifile) do
  desc 'Manage yum repos'

  PROPERTIES = Puppet::Type.type(:yumrepo).validproperties

  # @return [Array<Puppet::Providers>] Return all the providers built up from
  #   discovered content on the local node.
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
          attributes_hash[key] = value
        elsif key == :name
          attributes_hash[:descr] = value
        end
      end
      instances << new(attributes_hash)
    end
  return instances
  end

  # @param resources [Array<Puppet::Resource>] Resources to prefetch.
  # @return [Array<Puppet::Resource>] Resources with providers set.
  def self.prefetch(resources)
    repos = instances
    resources.keys.each do |name|
      if provider = repos.find { |repo| repo.name == name }
        resources[name].provider = provider
      end
    end
  end

  # Return a list of existing directories that could contain repo files.  Fail if none found.
  # @param conf [String] Configuration file to look for directories in.
  # @param dirs [Array] Default locations for yum repos.
  # @return [Array] Directories that were found to exist on the node.
  def self.reposdir(conf='/etc/yum.conf', dirs=['/etc/yum.repos.d', '/etc/yum/repos.d'])
    reposdir = find_conf_value('reposdir', conf)
    dirs << reposdir if reposdir

    # We can't use the below due to Ruby 1.8.7
    # dirs.select! { |dir| Puppet::FileSystem.exist?(dir) }
    dirs.delete_if { |dir| ! Puppet::FileSystem.exist?(dir)  }
    if dirs.empty?
      fail('No yum directories were found on the local filesystem')
    else
      return dirs
    end
  end

  # Helper method to look up specific values in ini style files.
  # @todo Migrate this into Puppet::Util::IniConfig.
  # @param value [String] Value to look for in the configuration file.
  # @param conf [String] Configuration file to check for value.
  # @return [String] The value of a looked up key from the configuration file.
  def self.find_conf_value(value, conf='/etc/yum.conf')
    if Puppet::FileSystem.exist?(conf)
      contents = Puppet::FileSystem.read(conf)
      match = /^#{value}\s*=\s*(.*)/.match(contents)
    end

    return match.captures[0] if match
  end

  # Build a virtual inifile by reading in numerous .repo
  # files into a single virtual file to ease manipulation.
  # @return [Puppet::Util::IniConfig::File] The virtual inifile representing
  #   multiple real files.
  def self.virtual_inifile
    unless @virtual
      @virtual = Puppet::Util::IniConfig::File.new
      reposdir.each do |dir|
        Dir.glob("#{dir}/*.repo").each do |file|
          @virtual.read(file) if Puppet::FileSystem.file?(file)
        end
      end
    end
    return @virtual
  end

  # @param key [String] The property to look up.
  # @return [Boolean] Returns true if the property is defined in the type.
  def self.valid_property?(key)
    PROPERTIES.include?(key)
  end

  # We need to return a valid section from the larger virtual inifile here,
  # which we do by first looking it up and then creating a new section for
  # the appropriate name if none was found.
  # @param name [String] Section name to lookup in the virtual inifile.
  # @return [Puppet::Util::IniConfig] The IniConfig section
  def self.section(name)
    result = self.virtual_inifile[name]
    # Create a new section if not found.
    unless result
      # Previously we did an .each on reposdir with the effect that we
      # constantly created and overwrote result until the last entry of
      # the array.  This was done because the ordering is
      # [defaults, custom] for reposdir and we want to use the custom if
      # we have it and the defaults if not.
      path = ::File.join(reposdir.last, "#{name}.repo")
      Puppet.info("create new repo #{name} in file #{path}")
      result = self.virtual_inifile.add_section(name, path)
    end
    result
  end

  # Here we store all modifications to disk, forcing the output file to 0644 if it differs.
  # @return [void]
  def self.store
    inifile = self.virtual_inifile
    inifile.store

    target_mode = 0644
    inifile.each_file do |file|
      current_mode = Puppet::FileSystem.stat(file).mode & 0777
      unless current_mode == target_mode
        Puppet.info "changing mode of #{file} from %03o to %03o" % [current_mode, target_mode]
        Puppet::FileSystem.chmod(target_mode, file)
      end
    end
  end

  # @return [void]
  def create
    @property_hash[:ensure] = :present

    new_section = current_section

    # We fetch a list of properties from the type, then iterate
    # over them, avoiding ensure.  We're relying on .should to
    # check if the property has been set and should be modified,
    # and if so we set it in the virtual inifile.
    PROPERTIES.each do |property|
      next if property == :ensure


      if value = @resource.should(property)
        self.send("#{property}=", value)
      end
    end
  end

  # @return [Boolean] Returns true if ensure => present.
  def exists?
    @property_hash[:ensure] == :present
  end

  # We don't actually destroy the file here, merely mark it for
  # destruction in the section.
  # @return [void]
  def destroy
    # Flag file for deletion on flush.
    current_section.destroy=(true)

    @property_hash.clear
  end

  # @return [void]
  def flush
    self.class.store
  end

  # Generate setters and getters for our INI properties.
  PROPERTIES.each do |property|
    # The ensure property uses #create, #exists, and #destroy we can't generate
    # meaningful setters and getters for this
    next if property == :ensure

    define_method(property) do
      get_property(property)
    end

    define_method("#{property}=") do |value|
      set_property(property, value)
    end
  end

  # Map the yumrepo 'descr' type property to the 'name' INI property.
  def descr
    if ! @property_hash.has_key?(:descr)
      @property_hash[:descr] = current_section['name']
    end
    value = @property_hash[:descr]
    value.nil? ? :absent : value
  end

  def descr=(value)
    value = (value == :absent ? nil : value)
    current_section['name'] = value
    @property_hash[:descr] = value
  end

  private

  def get_property(property)
    if ! @property_hash.has_key?(property)
      @property_hash[property] = current_section[property.to_s]
    end
    value = @property_hash[property]
    value.nil? ? :absent : value
  end

  def set_property(property, value)
    value = (value == :absent ? nil : value)
    current_section[property.to_s] = value
    @property_hash[property] = value
  end

  # @return [void]
  def section(name)
    self.class.section(name)
  end

  def current_section
    self.class.section(self.name)
  end
end
