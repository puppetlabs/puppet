# The client for interacting with the puppetmaster config server.
require 'sync'
require 'timeout'
require 'puppet/network/http_pool'
require 'puppet/util'
require 'securerandom'

class Puppet::Configurer
  require 'puppet/configurer/fact_handler'
  require 'puppet/configurer/plugin_handler'
  require 'puppet/configurer/downloader_factory'

  include Puppet::Configurer::FactHandler

  # For benchmarking
  include Puppet::Util

  attr_reader :compile_time, :environment

  # Provide more helpful strings to the logging that the Agent does
  def self.to_s
    "Puppet configuration client"
  end

  def execute_postrun_command
    execute_from_setting(:postrun_command)
  end

  def execute_prerun_command
    execute_from_setting(:prerun_command)
  end

  # Initialize and load storage
  def init_storage
      Puppet::Util::Storage.load
      @compile_time ||= Puppet::Util::Storage.cache(:configuration)[:compile_time]
  rescue => detail
    Puppet.log_exception(detail, "Removing corrupt state file #{Puppet[:statefile]}: #{detail}")
    begin
      Puppet::FileSystem.unlink(Puppet[:statefile])
      retry
    rescue => detail
      raise Puppet::Error.new("Cannot remove #{Puppet[:statefile]}: #{detail}", detail)
    end
  end

  def initialize(factory = Puppet::Configurer::DownloaderFactory.new)
    Puppet.settings.use(:main, :ssl, :agent)

    @running = false
    @splayed = false
    @environment = Puppet[:environment]
    @transaction_uuid = SecureRandom.uuid
    @handler = Puppet::Configurer::PluginHandler.new(factory)
  end

  # Get the remote catalog, yo.  Returns nil if no catalog can be found.
  def retrieve_catalog(query_options)
    query_options ||= {}
    # First try it with no cache, then with the cache.
    unless (Puppet[:use_cached_catalog] and result = retrieve_catalog_from_cache(query_options)) or result = retrieve_new_catalog(query_options)
      if ! Puppet[:usecacheonfailure]
        Puppet.warning "Not using cache on failed catalog"
        return nil
      end
      result = retrieve_catalog_from_cache(query_options)
    end

    return nil unless result

    convert_catalog(result, @duration)
  end

  # Convert a plain resource catalog into our full host catalog.
  def convert_catalog(result, duration)
    catalog = result.to_ral
    catalog.finalize
    catalog.retrieval_duration = duration
    catalog.write_class_file
    catalog.write_resource_file
    catalog
  end

  def get_facts(options)
    if options[:pluginsync]
      remote_environment_for_plugins = Puppet::Node::Environment.remote(@environment)
      download_plugins(remote_environment_for_plugins)
    end

    if Puppet::Resource::Catalog.indirection.terminus_class == :rest
      # This is a bit complicated.  We need the serialized and escaped facts,
      # and we need to know which format they're encoded in.  Thus, we
      # get a hash with both of these pieces of information.
      #
      # facts_for_uploading may set Puppet[:node_name_value] as a side effect
      return facts_for_uploading
    end
  end

  def prepare_and_retrieve_catalog(options, query_options)
    # set report host name now that we have the fact
    options[:report].host = Puppet[:node_name_value]

    unless catalog = (options.delete(:catalog) || retrieve_catalog(query_options))
      Puppet.err "Could not retrieve catalog; skipping run"
      return
    end
    catalog
  end

  # Retrieve (optionally) and apply a catalog. If a catalog is passed in
  # the options, then apply that one, otherwise retrieve it.
  def apply_catalog(catalog, options)
    report = options[:report]
    report.configuration_version = catalog.version

    benchmark(:notice, "Finished catalog run") do
      catalog.apply(options)
    end

    report.finalize_report
    report
  end

  # The code that actually runs the catalog.
  # This just passes any options on to the catalog,
  # which accepts :tags and :ignoreschedules.
  def run(options = {})
    pool = Puppet::Network::HTTP::Pool.new(Puppet[:http_keepalive_timeout])
    begin
      Puppet.override(:http_pool => pool) do
        run_internal(options)
      end
    ensure
      pool.close
    end
  end

  def run_internal(options)
    # We create the report pre-populated with default settings for
    # environment and transaction_uuid very early, this is to ensure
    # they are sent regardless of any catalog compilation failures or
    # exceptions.
    options[:report] ||= Puppet::Transaction::Report.new("apply", nil, @environment, @transaction_uuid)
    report = options[:report]
    init_storage

    Puppet::Util::Log.newdestination(report)

    begin
      unless Puppet[:node_name_fact].empty?
        query_options = get_facts(options)
      end

      # We only need to find out the environment to run in if we don't already have a catalog
      unless options[:catalog]
        begin
          if node = Puppet::Node.indirection.find(Puppet[:node_name_value],
              :environment => @environment, :ignore_cache => true, :transaction_uuid => @transaction_uuid,
              :fail_on_404 => true)

            # If we have deserialized a node from a rest call, we want to set
            # an environment instance as a simple 'remote' environment reference.
            if !node.has_environment_instance? && node.environment_name
              node.environment = Puppet::Node::Environment.remote(node.environment_name)
            end

            if node.environment.to_s != @environment
              Puppet.warning "Local environment: \"#{@environment}\" doesn't match server specified node environment \"#{node.environment}\", switching agent to \"#{node.environment}\"."
              @environment = node.environment.to_s
              report.environment = @environment
              query_options = nil
            end
          end
        rescue SystemExit,NoMemoryError
          raise
        rescue Exception => detail
          Puppet.warning("Unable to fetch my node definition, but the agent run will continue:")
          Puppet.warning(detail)
        end
      end

      current_environment = Puppet.lookup(:current_environment)
      local_node_environment =
      if current_environment.name == @environment.intern
        current_environment
      else
        Puppet::Node::Environment.create(@environment,
                                         current_environment.modulepath,
                                         current_environment.manifest,
                                         current_environment.config_version)
      end
      Puppet.push_context({:current_environment => local_node_environment}, "Local node environment for configurer transaction")

      query_options = get_facts(options) unless query_options

      # get_facts returns nil during puppet apply
      query_options ||= {}
      query_options[:transaction_uuid] = @transaction_uuid

      unless catalog = prepare_and_retrieve_catalog(options, query_options)
        return nil
      end

      # Here we set the local environment based on what we get from the
      # catalog. Since a change in environment means a change in facts, and
      # facts may be used to determine which catalog we get, we need to
      # rerun the process if the environment is changed.
      tries = 0
      while catalog.environment and not catalog.environment.empty? and catalog.environment != @environment
        if tries > 3
          raise Puppet::Error, "Catalog environment didn't stabilize after #{tries} fetches, aborting run"
        end
        Puppet.warning "Local environment: \"#{@environment}\" doesn't match server specified environment \"#{catalog.environment}\", restarting agent run with environment \"#{catalog.environment}\""
        @environment = catalog.environment
        report.environment = @environment
        return nil unless catalog = prepare_and_retrieve_catalog(options, query_options)
        tries += 1
      end

      execute_prerun_command or return nil
      apply_catalog(catalog, options)
      report.exit_status
    rescue => detail
      Puppet.log_exception(detail, "Failed to apply catalog: #{detail}")
      return nil
    ensure
      execute_postrun_command or return nil
    end
  ensure
    # Between Puppet runs we need to forget the cached values.  This lets us
    # pick up on new functions installed by gems or new modules being added
    # without the daemon being restarted.
    $env_module_directories = nil

    Puppet::Util::Log.close(report)
    send_report(report)
    Puppet.pop_context
  end
  private :run_internal

  def send_report(report)
    puts report.summary if Puppet[:summarize]
    save_last_run_summary(report)
    Puppet::Transaction::Report.indirection.save(report, nil, :environment => @environment) if Puppet[:report]
  rescue => detail
    Puppet.log_exception(detail, "Could not send report: #{detail}")
  end

  def save_last_run_summary(report)
    mode = Puppet.settings.setting(:lastrunfile).mode
    Puppet::Util.replace_file(Puppet[:lastrunfile], mode) do |fh|
      fh.print YAML.dump(report.raw_summary)
    end
  rescue => detail
    Puppet.log_exception(detail, "Could not save last run local report: #{detail}")
  end

  private

  def execute_from_setting(setting)
    return true if (command = Puppet[setting]) == ""

    begin
      Puppet::Util::Execution.execute([command])
      true
    rescue => detail
      Puppet.log_exception(detail, "Could not run command from #{setting}: #{detail}")
      false
    end
  end

  def retrieve_catalog_from_cache(query_options)
    result = nil
    @duration = thinmark do
      result = Puppet::Resource::Catalog.indirection.find(Puppet[:node_name_value],
        query_options.merge(:ignore_terminus => true, :environment => @environment))
    end
    Puppet.notice "Using cached catalog"
    result
  rescue => detail
    Puppet.log_exception(detail, "Could not retrieve catalog from cache: #{detail}")
    return nil
  end

  def retrieve_new_catalog(query_options)
    result = nil
    @duration = thinmark do
      result = Puppet::Resource::Catalog.indirection.find(Puppet[:node_name_value],
        query_options.merge(:ignore_cache => true, :environment => @environment, :fail_on_404 => true))
    end
    result
  rescue SystemExit,NoMemoryError
    raise
  rescue Exception => detail
    Puppet.log_exception(detail, "Could not retrieve catalog from remote server: #{detail}")
    return nil
  end

  def download_plugins(remote_environment_for_plugins)
    @handler.download_plugins(remote_environment_for_plugins)
  end
end
