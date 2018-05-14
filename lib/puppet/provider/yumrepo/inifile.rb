require 'puppet/util/inifile'

Puppet::Type.type(:yumrepo).provide(:inifile) do
  desc <<-EOD
    Manage yum repo configurations by parsing yum INI configuration files.

    ### Fetching instances

    When fetching repo instances, directory entries in '/etc/yum/repos.d',
    '/etc/yum.repos.d', and the directory optionally specified by the reposdir
    key in '/etc/yum.conf' will be checked. If a given directory does not exist it
    will be ignored. In addition, all sections in '/etc/yum.conf' aside from
    'main' will be created as sections.

    ### Storing instances

    When creating a new repository, a new section will be added in the first
    yum repo directory that exists. The custom directory specified by the
    '/etc/yum.conf' reposdir property is checked first, followed by
    '/etc/yum/repos.d', and then '/etc/yum.repos.d'. If none of these exist, the
    section will be created in '/etc/yum.conf'.
  EOD

  PROPERTIES = Puppet::Type.type(:yumrepo).validproperties

  # Retrieve all providers based on existing yum repositories
  #
  # @api public
  # @return [Array<Puppet::Provider>] providers generated from existing yum
  #   repository definitions.
  def self.instances
    instances = []

    virtual_inifile.each_section do |section|
      # Ignore the 'main' section in yum.conf since it's not a repository.
      next if section.name == "main"

      attributes_hash = {:name => section.name, :ensure => :present, :provider => :yumrepo}

      section.entries.each do |key, value|
        key = key.to_sym
        if valid_property?(key)
          attributes_hash[key] = value
        elsif key == :name
          attributes_hash[:descr] = value
        end
      end
      instances << new(attributes_hash)
    end

    instances
  end

  # Match catalog type instances to provider instances.
  #
  # @api public
  # @param resources [Array<Puppet::Type::Yumrepo>] Resources to prefetch.
  # @return [void]
  def self.prefetch(resources)
    repos = instances
    resources.each_key do |name|
      if provider = repos.find { |repo| repo.name == name }
        resources[name].provider = provider
      end
    end
  end

  # Return a list of existing directories that could contain repo files.
  #
  # @api private
  # @param conf [String] Configuration file to look for directories in.
  # @param dirs [Array<String>] Default locations for yum repos.
  # @return [Array<String>] All present directories that may contain yum repo configs.
  def self.reposdir(conf='/etc/yum.conf', dirs=['/etc/yum.repos.d', '/etc/yum/repos.d'])
    reposdir = find_conf_value('reposdir', conf)
    # Use directories in reposdir if they are set instead of default
    if reposdir
      # Follow the code from the yum/config.py
      reposdir.gsub!("\n", ' ')
      reposdir.gsub!(',', ' ')
      dirs = reposdir.split
    end
    dirs.select! { |dir| Puppet::FileSystem.exist?(dir) }
    if dirs.empty?
      Puppet.debug('No yum directories were found on the local filesystem')
    end

    dirs
  end

  # Used for testing only
  # @api private
  def self.clear
    @virtual = nil
  end

  # Helper method to look up specific values in ini style files.
  #
  # @api private
  # @param value [String] Value to look for in the configuration file.
  # @param conf [String] Configuration file to check for value.
  # @return [String] The value of a looked up key from the configuration file.
  def self.find_conf_value(value, conf='/etc/yum.conf')
    if Puppet::FileSystem.exist?(conf)
      file = Puppet::Util::IniConfig::PhysicalFile.new(conf)
      file.read
      if (main = file.get_section('main'))
        main[value]
      end
    end
  end

  # Enumerate all files that may contain yum repository configs.
  # '/etc/yum.conf' is always included.
  #
  # @api private
  # @return [Array<String>
  def self.repofiles
    files = ["/etc/yum.conf"]
    reposdir.each do |dir|
      Dir.glob("#{dir}/*.repo").each do |file|
        files << file
      end
    end

    files
  end

  # Build a virtual inifile by reading in numerous .repo files into a single
  # virtual file to ease manipulation.
  # @api private
  # @return [Puppet::Util::IniConfig::File] The virtual inifile representing
  #   multiple real files.
  def self.virtual_inifile
    unless @virtual
      @virtual = Puppet::Util::IniConfig::File.new
      self.repofiles.each do |file|
        @virtual.read(file) if Puppet::FileSystem.file?(file)
      end
    end
    return @virtual
  end

  # Is the given key a valid type property?
  #
  # @api private
  # @param key [String] The property to look up.
  # @return [Boolean] Returns true if the property is defined in the type.
  def self.valid_property?(key)
    PROPERTIES.include?(key)
  end

  # Return an existing INI section or create a new section in the default location
  #
  # The default location is determined based on what yum repo directories
  # and files are present. If /etc/yum.conf has a value for 'reposdir' then that
  # is preferred. If no such INI property is found then the first default yum
  # repo directory that is present is used. If no default directories exist then
  # /etc/yum.conf is used.
  #
  # @param name [String] Section name to lookup in the virtual inifile.
  # @return [Puppet::Util::IniConfig] The IniConfig section
  def self.section(name)
    result = self.virtual_inifile[name]
    # Create a new section if not found.
    unless result
      path = getRepoPath(name)
      result = self.virtual_inifile.add_section(name, path)
    end
    result
  end

  # Save all yum repository files and force the mode to 0644
  # @api private
  # @return [void]
  def self.store(resource)
    inifile = self.virtual_inifile
    inifile.store

    target_mode = 0644
    inifile.each_file do |file|
      next unless Puppet::FileSystem.exist?(file)
      current_mode = Puppet::FileSystem.stat(file).mode & 0777
      unless current_mode == target_mode
        resource.info _("changing mode of %{file} from %{current_mode} to %{target_mode}") %
                          { file: file, current_mode: "%03o" % current_mode, target_mode: "%03o" % target_mode }
        Puppet::FileSystem.chmod(target_mode, file)
      end
    end
  end

  def self.getRepoPath(name)
    dirs = reposdir()
    if dirs.empty?
      # If no repo directories are present, default to using yum.conf.
      path = '/etc/yum.conf'
    else
      # The ordering of reposdir is [defaults, custom], and we want to use
      # the custom directory if present.
      path = File.join(dirs.last, "#{name}.repo")
    end
    path
  end

  # Create a new section for the given repository and set all the specified
  # properties in the section.
  #
  # @api public
  # @return [void]
  def create
    @property_hash[:ensure] = :present

    # Check to see if the file that would be created in the
    # default location for the yumrepo already exists on disk.
    # If it does, read it in to the virtual inifile
    path = self.class.getRepoPath(name)
    self.class.virtual_inifile.read(path) if Puppet::FileSystem.file?(path)

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

  # Does the given repository already exist?
  #
  # @api public
  # @return [Boolean]
  def exists?
    @property_hash[:ensure] == :present
  end

  # Mark the given repository section for destruction.
  #
  # The actual removal of the section will be handled by {#flush} after the
  # resource has been fully evaluated.
  #
  # @api public
  # @return [void]
  def destroy
    # Flag file for deletion on flush.
    current_section.destroy=(true)

    @property_hash.clear
  end

  # Finalize the application of the given resource.
  #
  # @api public
  # @return [void]
  def flush
    self.class.store(self)
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

  def section(name)
    self.class.section(name)
  end

  def current_section
    self.class.section(self.name)
  end
end
