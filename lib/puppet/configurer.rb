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

  def self.should_pluginsync?
    if Puppet.settings.set_by_cli?(:pluginsync) || Puppet.settings.set_by_config?(:pluginsync)
      Puppet[:pluginsync]
    else
      if Puppet[:use_cached_catalog]
        false
      else
        true
      end
    end
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
    @running = false
    @splayed = false
    @cached_catalog_status = 'not_used'
    @environment = Puppet[:environment]
    @transaction_uuid = SecureRandom.uuid
    @static_catalog = true
    @checksum_type = Puppet[:supported_checksum_types]
    @handler = Puppet::Configurer::PluginHandler.new(factory)
  end

  # Get the remote catalog, yo.  Returns nil if no catalog can be found.
  def retrieve_catalog(query_options)
    query_options ||= {}
    if (Puppet[:use_cached_catalog] && result = retrieve_catalog_from_cache(query_options))
      @cached_catalog_status = 'explicitly_requested'

      Puppet.info "Using cached catalog from environment '#{result.environment}'"
    else
      result = retrieve_new_catalog(query_options)

      if !result
        if !Puppet[:usecacheonfailure]
          Puppet.warning "Not using cache on failed catalog"
          return nil
        end

        result = retrieve_catalog_from_cache(query_options)

        if result
          # don't use use cached catalog if it doesn't match server specified environment
          if @node_environment && result.environment != @environment
            Puppet.err "Not using cached catalog because its environment '#{result.environment}' does not match '#{@environment}'"
            return nil
          end

          @cached_catalog_status = 'on_failure'
          Puppet.info "Using cached catalog from environment '#{result.environment}'"
        end
      end
    end

    result
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

    facts_hash = {}
    if Puppet::Resource::Catalog.indirection.terminus_class == :rest
      # This is a bit complicated.  We need the serialized and escaped facts,
      # and we need to know which format they're encoded in.  Thus, we
      # get a hash with both of these pieces of information.
      #
      # facts_for_uploading may set Puppet[:node_name_value] as a side effect
      facts_hash = facts_for_uploading
    end
    facts_hash
  end

  def prepare_and_retrieve_catalog(options, query_options)
    # set report host name now that we have the fact
    options[:report].host = Puppet[:node_name_value]
    query_options[:transaction_uuid] = @transaction_uuid
    query_options[:static_catalog] = @static_catalog

    # Query params don't enforce ordered evaluation, so munge this list into a
    # dot-separated string.
    query_options[:checksum_type] = @checksum_type.join('.')

    # apply passes in ral catalog
    catalog = options.delete(:catalog)
    return catalog if catalog

    # retrieve_catalog returns json catalog
    catalog = retrieve_catalog(query_options)
    return convert_catalog(catalog, @duration) if catalog

    Puppet.err "Could not retrieve catalog; skipping run"
    nil
  end

  def prepare_and_retrieve_catalog_from_cache
    result = retrieve_catalog_from_cache({:transaction_uuid => @transaction_uuid, :static_catalog => @static_catalog})
    if result
      Puppet.info "Using cached catalog from environment '#{result.environment}'"
      return convert_catalog(result, @duration)
    end
    nil
  end

  # Retrieve (optionally) and apply a catalog. If a catalog is passed in
  # the options, then apply that one, otherwise retrieve it.
  def apply_catalog(catalog, options)
    report = options[:report]
    begin
      report.configuration_version = catalog.version

      benchmark(:notice, "Applied catalog") do
        catalog.apply(options)
      end
    ensure
      report.finalize_report
    end
    report
  end

  # The code that actually runs the catalog.
  # This just passes any options on to the catalog,
  # which accepts :tags and :ignoreschedules.
  def run(options = {})
    pool = Puppet::Network::HTTP::Pool.new(Puppet[:http_keepalive_timeout])
    # We create the report pre-populated with default settings for
    # environment and transaction_uuid very early, this is to ensure
    # they are sent regardless of any catalog compilation failures or
    # exceptions.
    options[:report] ||= Puppet::Transaction::Report.new("apply", nil, @environment, @transaction_uuid)
    report = options[:report]
    init_storage

    Puppet::Util::Log.newdestination(report)

    begin
      Puppet.override(:http_pool => pool) do

        # Skip failover logic if the server_list setting is empty
        if Puppet.settings[:server_list].nil? || Puppet.settings[:server_list].empty?
          do_failover = false;
        else
          do_failover = true
        end
        # When we are passed a catalog, that means we're in apply
        # mode. We shouldn't try to do any failover in that case.
        if options[:catalog].nil? && do_failover
          found = find_functional_server()
          server = found[:server]
          if server.nil?
            Puppet.warning "Could not select a functional puppet master"
            server = [nil, nil]
          end
          Puppet.override(:server => server[0], :serverport => server[1]) do
            if !server.first.nil?
              Puppet.debug "Selected master: #{server[0]}:#{server[1]}"
              report.master_used = "#{server[0]}:#{server[1]}"
            end

            run_internal(options.merge(:node => found[:node]))
          end
        else
          run_internal(options)
        end
      end
    ensure
      pool.close
    end
  end

  def run_internal(options)
    report = options[:report]

    # If a cached catalog is explicitly requested, attempt to retrieve it. Skip the node request,
    # don't pluginsync and switch to the catalog's environment if we successfully retrieve it.
    if Puppet[:use_cached_catalog]
      if catalog = prepare_and_retrieve_catalog_from_cache
        options[:catalog] = catalog
        @cached_catalog_status = 'explicitly_requested'

        if @environment != catalog.environment && !Puppet[:strict_environment_mode]
          Puppet.notice "Local environment: '#{@environment}' doesn't match the environment of the cached catalog '#{catalog.environment}', switching agent to '#{catalog.environment}'."
          @environment = catalog.environment
        end

        report.environment = @environment
      else
        # Don't try to retrieve a catalog from the cache again after we've already
        # failed to do so the first time.
        Puppet[:use_cached_catalog] = false
        Puppet[:usecacheonfailure] = false
        options[:pluginsync] = Puppet::Configurer.should_pluginsync?
      end
    end

    begin
      unless Puppet[:node_name_fact].empty?
        query_options = get_facts(options)
      end

      configured_environment = Puppet[:environment] if Puppet.settings.set_by_config?(:environment)

      # We only need to find out the environment to run in if we don't already have a catalog
      unless (options[:catalog] || Puppet[:strict_environment_mode])
        begin
          if node = options[:node] || Puppet::Node.indirection.find(Puppet[:node_name_value],
              :environment => Puppet::Node::Environment.remote(@environment),
              :configured_environment => configured_environment,
              :ignore_cache => true,
              :transaction_uuid => @transaction_uuid,
              :fail_on_404 => true)

            # If we have deserialized a node from a rest call, we want to set
            # an environment instance as a simple 'remote' environment reference.
            if !node.has_environment_instance? && node.environment_name
              node.environment = Puppet::Node::Environment.remote(node.environment_name)
            end

            @node_environment = node.environment.to_s

            if node.environment.to_s != @environment
              Puppet.notice "Local environment: '#{@environment}' doesn't match server specified node environment '#{node.environment}', switching agent to '#{node.environment}'."
              @environment = node.environment.to_s
              report.environment = @environment
              query_options = nil
            else
              Puppet.info "Using configured environment '#{@environment}'"
            end
          end
        rescue StandardError => detail
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
      query_options[:configured_environment] = configured_environment

      unless catalog = prepare_and_retrieve_catalog(options, query_options)
        return nil
      end

      if Puppet[:strict_environment_mode] && catalog.environment != @environment
        Puppet.err "Not using catalog because its environment '#{catalog.environment}' does not match agent specified environment '#{@environment}' and strict_environment_mode is set"
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
        Puppet.notice "Local environment: '#{@environment}' doesn't match server specified environment '#{catalog.environment}', restarting agent run with environment '#{catalog.environment}'"
        @environment = catalog.environment
        report.environment = @environment

        query_options = get_facts(options)
        query_options[:configured_environment] = configured_environment

        return nil unless catalog = prepare_and_retrieve_catalog(options, query_options)
        tries += 1
      end

      execute_prerun_command or return nil

      options[:report].code_id = catalog.code_id
      options[:report].catalog_uuid = catalog.catalog_uuid
      options[:report].cached_catalog_status = @cached_catalog_status
      apply_catalog(catalog, options)
      report.exit_status
    rescue => detail
      Puppet.log_exception(detail, "Failed to apply catalog: #{detail}")
      return nil
    ensure
      execute_postrun_command or return nil
    end
  ensure
    report.cached_catalog_status ||= @cached_catalog_status
    Puppet::Util::Log.close(report)
    send_report(report)
    Puppet.pop_context
  end
  private :run_internal

  def find_functional_server()
    configured_environment = Puppet[:environment] if Puppet.settings.set_by_config?(:environment)

    node = nil
    selected_server = Puppet.settings[:server_list].find do |server|
      # Puppet.override doesn't return the result of its block, so we
      # need to handle this manually
      found = false
      server[1] ||= Puppet[:masterport]
      Puppet.override(:server => server[0], :serverport => server[1]) do
        begin
          node = Puppet::Node.indirection.find(Puppet[:node_name_value],
              :environment => Puppet::Node::Environment.remote(@environment),
              :configured_environment => configured_environment,
              :ignore_cache => true,
              :transaction_uuid => @transaction_uuid,
              :fail_on_404 => false)
          found = true
        rescue Exception => e
          # Nothing to see here
        end
      end
      found
    end
    { :node => node,
      :server => selected_server }
  end
  private :find_functional_server

  def send_report(report)
    puts report.summary if Puppet[:summarize]
    save_last_run_summary(report)
    Puppet::Transaction::Report.indirection.save(report, nil, :environment => Puppet::Node::Environment.remote(@environment)) if Puppet[:report]
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
        query_options.merge(:ignore_terminus => true, :environment => Puppet::Node::Environment.remote(@environment)))
    end
    result
  rescue => detail
    Puppet.log_exception(detail, "Could not retrieve catalog from cache: #{detail}")
    return nil
  end

  def retrieve_new_catalog(query_options)
    result = nil
    @duration = thinmark do
      result = Puppet::Resource::Catalog.indirection.find(Puppet[:node_name_value],
        query_options.merge(:ignore_cache => true, :environment => Puppet::Node::Environment.remote(@environment), :fail_on_404 => true))
    end
    result
  rescue StandardError => detail
    Puppet.log_exception(detail, "Could not retrieve catalog from remote server: #{detail}")
    return nil
  end

  def download_plugins(remote_environment_for_plugins)
    @handler.download_plugins(remote_environment_for_plugins)
  end
end
