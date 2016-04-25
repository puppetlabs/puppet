class Puppet::Provider::Package < Puppet::Provider
  # Prefetch our package list, yo.
  def self.prefetch(packages)
    instances.each do |prov|
      if pkg = packages[prov.name]
        pkg.provider = prov
      end
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

  # Wrap the has_command function to use this class's `execute` function
  def self.has_command(name, path, &block)
    if self.class.declared_feature?(:settable_environment)
      super(name, path) do
        executor Puppet::Provider::Package
        self.instance_eval(block) if block
      end
    else
      super(name, path, block)
    end
  end

  # Wrap the Puppet::Util::Execution.execute function to automatically
  # import the resource[:environment] hash into the execution environment,
  # if the :settable_environment is available
  def execute(command, options = nil)
    if self.class.declared_feature?(:settable_environment) and @resource and resource[:environment]
      if options.nil?
        # no options hash provided, provide our own
        options = { :custom_environment => @resource[:environment] }
      elsif options.has_key?(:custom_environment)
        # make a "safe" copy of options before modifying
        options = options.dup
        options[:custom_environment] = options[:custom_environment].merge(@resource[:environment])
      else
        # merge creates a new copy of the hash before merging
        options = options.merge(:custom_environment => @resource[:environment])
      end
    end
    if options.nil?
      Puppet::Util::Execution.execute(command)
    else
      Puppet::Util::Execution.execute(command, options)
    end
  end

  # Wrap the Puppet::Util::Execution.execpipe function to automatically
  # import the resource[:environment] hash into the execution environment,
  # if the :settable_environment is available
  def self.execpipe(command, failonfail = nil)
    execpipe_env = ENV.to_hash
    if self.class.declared_feature?(:settable_environment) and @resource and resource[:environment]
      execpipe_env.merge!( resource[:environment] )
    end
    Puppet::Util.withenv(execpipe_env) do
      if failonfail.nil?
        Puppet::Util::Execution.execpipe(command)
      else
        Puppet::Util::Execution.execpipe(command, failonfail)
      end
    end
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
