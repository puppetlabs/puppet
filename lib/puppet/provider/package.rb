class Puppet::Provider::Package < Puppet::Provider
  # Prefetch our package list, yo.
  def self.prefetch(packages)
    # Packages resources are deduplicated as they are stored in a hash by name.
    # A unique key would include name, provider, and target. See transaction.rb.

    # Collect providers and targets from all package resources with a target.
    default_targets = false
    targets = {}
    packages.each do |name, package|
      if package[:target]
        if package[:target] == :default
          default_targets = true
        else
          targets[package[:target]] = package.provider.class
        end
      end
    end

    # Instances for each package provider without a targeted package command.
    if default_targets == true || (default_targets == false && targets.empty?)
      instances.each do |instance|
        self.debug "Prefetched instance: #{instance.name}"
        # * See above comment regarding uniqueness.
        # if package = packages[instance.key]
          # if package[:target] && package[:target] == :default
          #  package.provider = instance
          # end
        # end
      end
    end

    # Instances for each package provider with a targeted package command.
    targets.each do |target, provider|
      provider::instances(target).each do |instance|
        self.debug "Prefetched via: #{target}, instance: #{instance.name}"
        # * See above comment regarding uniqueness.
        # if package = packages[instance.key]
          # if package[:target] && package[:target] == target
          #   package.provider = instance
          # end
        # end
      end
    end
  end

  # Returns a human readable string with information about the package, provider, and target.
  def to_s
    "#{@resource}(provider=#{self.class.name})(target=#{resource_target})"
  end

  # Not all providers are targetable, not all targetable packages have a target.
  def resource_target
    resource[:target] || :default
  end

  # Instance method to determine the package command of a targetable package resource.
  #
  # key: the symbol for the default package command in the commands hash
  def resource_or_default_package_command(key)
    if resource[:target] && resource[:target] != :default
      self.class.validate_package_command(resource[:target])
      resource[:target]
    else
      self.class.validate_package_command(command(key))
      command(key)
    end
  end

  # Class method to determine the package command of a targetable package provider.
  #
  # cmd: the full path to the target package command
  # key: the symbol for the default package command in the commands hash
  def self.command_or_default_package_command(cmd, key)
    if cmd
      validate_package_command(cmd)
      cmd
    else
      validate_package_command(command(key))
      command(key)
    end
  end

  # Targetable providers use has_command/is_optional to defer evaluation of provider suitability.
  #
  # cmd: the full path to the package command
  def self.validate_package_command(cmd)
    unless cmd
      raise Puppet::Error, _('package command not specified')
    end
    unless File.file?(cmd)
      raise Puppet::Error, _("package command '%{cmd}' does not exist") % { cmd: cmd }
    end
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
