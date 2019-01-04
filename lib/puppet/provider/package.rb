class Puppet::Provider::Package < Puppet::Provider
  # Prefetch our package list, yo.
  #
  # The packages hash is deduplicated, as the hash is keyed by package name, in transaction.rb.
  # A unique key would be: [name, provider, command].
  def self.prefetch(packages)
    # Instances for each package provider.
    instances.each do |instance|
      if packages[instance.name]
        packages[instance.name].provider = instance
      end
      self.debug "Prefetched instance: #{instance.name}"
    end

    # Collect unique providers and commands from all package resources.
    targets = {}
    packages.each do |name, package|
      if package[:command] && package[:command] != 'default'
        targets[package[:command]] = package.provider.class
      end
    end

    # Instances for each package provider with a targeted package command.
    targets.each do |target, provider|
      provider::instances(target).each do |instance|
        # Given that the packages hash is deduplicated, do not set provider:
        # if packages[instance.name]
        #   packages[instance.name].provider = instance
        # end
        # Inspection indicates that provider is already set anyway.
        self.debug "Prefetched via: #{target}, instance: #{instance.name}"
      end
    end
  end

  # Determine the package command of a targetable package resource.
  # Adds the resource command to the commands for the package provider, if necessary.
  # Returns the symbol for the resource command or default package command, or raises an error,
  #
  # key: the symbol for the default package command in the commands hash
  def resource_or_default_package_command(key)
    if resource[:command] && resource[:command] != 'default'
      resource_command = self.class.has_target_command(resource[:command])
      resource_command
    else
      self.class.validate_package_command(command(key))
      key
    end
  end

  # Define a resource package command, if necessary, and return its name as a symbol.
  #
  # cmd: the full path to the package command
  def self.has_target_command(cmd)
    cmd_sym = cmd.to_sym
    return cmd_sym if @commands[cmd_sym]
    command(cmd_sym, cmd)
    cmd_sym
  end

  # Targetable providers use has_command/is_optional to defer validation of provider suitability.
  # This validates the package command for provider suitability.
  #
  # cmd: the full path to the package command
  def self.validate_package_command(cmd)
    unless cmd
      raise Puppet::Error, _("Provider %{name} package command is not functional on this host") % { name: name }
    end
    unless File.file?(cmd)
      raise Puppet::Error, _("Provider %{name} package command '%{cmd}' does not exist on this host") % { name: name, cmd: cmd }
    end
  end

  # Return information about the package, provider, and command.
  def to_s
    "#{@resource}(provider=#{self.class.name})(command=#{resource_command})"
  end

  # Not all providers are targetable, not all targetable packages have a target.
  def resource_command
    resource[:command] || 'default'
  end

  # Clear out the cached values.
  def flush
    @property_hash.clear
  end

  # Look up the current status.
  def properties
    if @property_hash.empty?
      # For providers that support purging, default to purged; otherwise default to absent
      # Purged is the "most uninstalled" a package can be, so a purged package will be in-sync with
      # either `ensure => absent` or `ensure => purged`; an absent package will be out of sync with `ensure => purged`.
      default_status = self.class.feature?(:purgeable) ? :purged : :absent
      @property_hash = query || { :ensure => ( default_status )}
      @property_hash[:ensure] = default_status if @property_hash.empty?
    end
    @property_hash.dup
  end

  def validate_source(value)
    true
  end

  # Turns a array of options into flags to be passed to a command.
  # The options can be passed as a string or hash. Note that passing a hash
  # should only be used in case --foo=bar must be passed,
  # which can be accomplished with:
  #     install_options => [ { '--foo' => 'bar' } ]
  # Regular flags like '--foo' must be passed as a string.
  # @param options [Array]
  # @return Concatenated list of options
  # @api private
  def join_options(options)
    return unless options

    options.collect do |val|
      case val
        when Hash
          val.keys.sort.collect do |k|
            "#{k}=#{val[k]}"
          end
        else
          val
      end
    end.flatten
  end
end
