# The client for interacting with the puppetmaster config server.
require 'sync'
require 'timeout'
require 'puppet/network/http_pool'
require 'puppet/util'
require 'securerandom'
#require 'puppet/parser/script_compiler'
require 'puppet/pops/evaluator/deferred_resolver'

class Puppet::Configurer
  require 'puppet/configurer/fact_handler'
  require 'puppet/configurer/plugin_handler'

  include Puppet::Configurer::FactHandler

  # For benchmarking
  include Puppet::Util

  attr_reader :environment

  # Provide more helpful strings to the logging that the Agent does
  def self.to_s
    _("Puppet configuration client")
  end

  def self.should_pluginsync?
    if Puppet[:use_cached_catalog]
      false
    else
      true
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
  rescue => detail
    Puppet.log_exception(detail, _("Removing corrupt state file %{file}: %{detail}") % { file: Puppet[:statefile], detail: detail })
    begin
      Puppet::FileSystem.unlink(Puppet[:statefile])
      retry
    rescue => detail
      raise Puppet::Error.new(_("Cannot remove %{file}: %{detail}") % { file: Puppet[:statefile], detail: detail }, detail)
    end
  end

  def initialize(transaction_uuid = nil, job_id = nil)
    @running = false
    @splayed = false
    @cached_catalog_status = 'not_used'
    @environment = Puppet[:environment]
    @transaction_uuid = transaction_uuid || SecureRandom.uuid
    @job_id = job_id
    @static_catalog = true
    @checksum_type = Puppet[:supported_checksum_types]
    @handler = Puppet::Configurer::PluginHandler.new()
  end

  # Get the remote catalog, yo.  Returns nil if no catalog can be found.
  def retrieve_catalog(query_options)
    query_options ||= {}
    if (Puppet[:use_cached_catalog] && result = retrieve_catalog_from_cache(query_options))
      @cached_catalog_status = 'explicitly_requested'

      Puppet.info _("Using cached catalog from environment '%{environment}'") % { environment: result.environment }
    else
      result = retrieve_new_catalog(query_options)

      if !result
        if !Puppet[:usecacheonfailure]
          Puppet.warning _("Not using cache on failed catalog")
          return nil
        end

        result = retrieve_catalog_from_cache(query_options)

        if result
          # don't use use cached catalog if it doesn't match server specified environment
          if @node_environment && result.environment != @environment
            Puppet.err _("Not using cached catalog because its environment '%{catalog_env}' does not match '%{local_env}'") % { catalog_env: result.environment, local_env: @environment }
            return nil
          end

          @cached_catalog_status = 'on_failure'
          Puppet.info _("Using cached catalog from environment '%{catalog_env}'") % { catalog_env: result.environment }
        end
      end
    end

    result
  end

  # Convert a plain resource catalog into our full host catalog.
  def convert_catalog(result, duration, options = {})
    catalog = nil

    catalog_conversion_time = thinmark do
      # Will mutate the result and replace all Deferred values with resolved values
      if facts = options[:convert_with_facts]
        Puppet::Pops::Evaluator::DeferredResolver.resolve_and_replace(facts, result)
      end

      catalog = result.to_ral
      catalog.finalize
      catalog.retrieval_duration = duration
      catalog.write_class_file
      catalog.write_resource_file
    end
    options[:report].add_times(:convert_catalog, catalog_conversion_time) if options[:report]

    catalog
  end

  def get_facts(options)
    if options[:pluginsync]
      plugin_sync_time = thinmark do
        remote_environment_for_plugins = Puppet::Node::Environment.remote(@environment)
        download_plugins(remote_environment_for_plugins)

        Puppet::GettextConfig.reset_text_domain('agent')
        Puppet::ModuleTranslations.load_from_vardir(Puppet[:vardir])
      end
      options[:report].add_times(:plugin_sync, plugin_sync_time) if options[:report]
    end

    facts_hash = {}
    if Puppet::Resource::Catalog.indirection.terminus_class == :rest
      # This is a bit complicated.  We need the serialized and escaped facts,
      # and we need to know which format they're encoded in.  Thus, we
      # get a hash with both of these pieces of information.
      #
      # facts_for_uploading may set Puppet[:node_name_value] as a side effect
      facter_time = thinmark do
        facts = find_facts
        options[:convert_with_facts] =  facts
        facts_hash = encode_facts(facts) # encode for uploading # was: facts_for_uploading
      end
      options[:report].add_times(:fact_generation, facter_time) if options[:report]
    end
    facts_hash
  end

  def prepare_and_retrieve_catalog(options, query_options)
    # set report host name now that we have the fact
    options[:report].host = Puppet[:node_name_value]
    query_options[:transaction_uuid] = @transaction_uuid
    query_options[:job_id] = @job_id
    query_options[:static_catalog] = @static_catalog

    # Query params don't enforce ordered evaluation, so munge this list into a
    # dot-separated string.
    query_options[:checksum_type] = @checksum_type.join('.')

    # apply passes in ral catalog
    catalog = options.delete(:catalog)
    return catalog if catalog

    # retrieve_catalog returns json catalog
    catalog = retrieve_catalog(query_options)
    return convert_catalog(catalog, @duration, options) if catalog

    Puppet.err _("Could not retrieve catalog; skipping run")
    nil
  end

  def prepare_and_retrieve_catalog_from_cache(options = {})
    result = retrieve_catalog_from_cache({:transaction_uuid => @transaction_uuid, :static_catalog => @static_catalog})
    if result
      Puppet.info _("Using cached catalog from environment '%{catalog_env}'") % { catalog_env: result.environment }
      # get facts now so that the convert_catalog method can resolve deferred values
      get_facts(options)
      return convert_catalog(result, @duration, options)
    end
    nil
  end

  # Apply supplied catalog and return associated application report
  def apply_catalog(catalog, options)
    report = options[:report]
    report.configuration_version = catalog.version

    benchmark(:notice, _("Applied catalog in %{seconds} seconds")) do
      apply_catalog_time = thinmark do
        catalog.apply(options)
      end
      options[:report].add_times(:catalog_application, apply_catalog_time)
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
    options[:report] ||= Puppet::Transaction::Report.new(nil, @environment, @transaction_uuid, @job_id)
    report = options[:report]
    init_storage

    Puppet::Util::Log.newdestination(report)

    completed = nil
    begin
      Puppet.override(:http_pool => pool) do

        # Skip failover logic if the server_list setting is empty
        if Puppet.settings[:server_list].nil? || Puppet.settings[:server_list].empty?
          do_failover = false
        else
          do_failover = true
        end
        # When we are passed a catalog, that means we're in apply
        # mode. We shouldn't try to do any failover in that case.
        if options[:catalog].nil? && do_failover
          server, port = find_functional_server
          if server.nil?
            raise Puppet::Error, _("Could not select a functional puppet master from server_list: '%{server_list}'") % { server_list: Puppet.settings.value(:server_list, Puppet[:environment].to_sym, true) }
          else
            #TRANSLATORS 'server_list' is the name of a setting and should not be translated
            Puppet.debug _("Selected puppet server from the `server_list` setting: %{server}:%{port}") % { server: server, port: port }
            report.master_used = "#{server}:#{port}"
          end
          Puppet.override(server: server, serverport: port) do
            completed = run_internal(options)
          end
        else
          completed = run_internal(options)
        end
      end
    ensure
      pool.close
    end

    completed ? report.exit_status : nil
  end

  def run_internal(options)
    start = Time.now
    report = options[:report]

    # If a cached catalog is explicitly requested, attempt to retrieve it. Skip the node request,
    # don't pluginsync and switch to the catalog's environment if we successfully retrieve it.
    if Puppet[:use_cached_catalog]
      Puppet::GettextConfig.reset_text_domain('agent')
      Puppet::ModuleTranslations.load_from_vardir(Puppet[:vardir])

      if catalog = prepare_and_retrieve_catalog_from_cache(options)
        options[:catalog] = catalog
        @cached_catalog_status = 'explicitly_requested'

        if @environment != catalog.environment && !Puppet[:strict_environment_mode]
          Puppet.notice _("Local environment: '%{local_env}' doesn't match the environment of the cached catalog '%{catalog_env}', switching agent to '%{catalog_env}'.") % { local_env: @environment, catalog_env: catalog.environment }
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
          node = nil
          node_retr_time = thinmark do
            node = Puppet::Node.indirection.find(Puppet[:node_name_value],
              :environment => Puppet::Node::Environment.remote(@environment),
              :configured_environment => configured_environment,
              :ignore_cache => true,
              :transaction_uuid => @transaction_uuid,
              :fail_on_404 => true)
          end
          options[:report].add_times(:node_retrieval, node_retr_time)

          if node
            # If we have deserialized a node from a rest call, we want to set
            # an environment instance as a simple 'remote' environment reference.
            if !node.has_environment_instance? && node.environment_name
              node.environment = Puppet::Node::Environment.remote(node.environment_name)
            end

            @node_environment = node.environment.to_s

            if node.environment.to_s != @environment
              Puppet.notice _("Local environment: '%{local_env}' doesn't match server specified node environment '%{node_env}', switching agent to '%{node_env}'.") % { local_env: @environment, node_env: node.environment }
              @environment = node.environment.to_s
              report.environment = @environment
              query_options = nil
            else
              Puppet.info _("Using configured environment '%{env}'") % { env: @environment }
            end
          end
        rescue StandardError => detail
          Puppet.warning(_("Unable to fetch my node definition, but the agent run will continue:"))
          Puppet.warning(detail)
        end
      end

      current_environment = Puppet.lookup(:current_environment)
      if current_environment.name == @environment.intern
        local_node_environment = current_environment
      else
        local_node_environment = Puppet::Node::Environment.create(@environment,
                                         current_environment.modulepath,
                                         current_environment.manifest,
                                         current_environment.config_version)
      end
      Puppet.push_context({
        :current_environment => local_node_environment, 
        :loaders => Puppet::Pops::Loaders.new(local_node_environment, true)
      }, "Local node environment for configurer transaction")

      query_options = get_facts(options) unless query_options
      query_options[:configured_environment] = configured_environment
      options[:convert_for_node] = node

      unless catalog = prepare_and_retrieve_catalog(options, query_options)
        return nil
      end

      if Puppet[:strict_environment_mode] && catalog.environment != @environment
        Puppet.err _("Not using catalog because its environment '%{catalog_env}' does not match agent specified environment '%{local_env}' and strict_environment_mode is set") % { catalog_env: catalog.environment, local_env: @environment }
        return nil
      end

      # Here we set the local environment based on what we get from the
      # catalog. Since a change in environment means a change in facts, and
      # facts may be used to determine which catalog we get, we need to
      # rerun the process if the environment is changed.
      tries = 0
      while catalog.environment and not catalog.environment.empty? and catalog.environment != @environment
        if tries > 3
          raise Puppet::Error, _("Catalog environment didn't stabilize after %{tries} fetches, aborting run") % { tries: tries }
        end
        Puppet.notice _("Local environment: '%{local_env}' doesn't match server specified environment '%{catalog_env}', restarting agent run with environment '%{catalog_env}'") % { local_env: @environment, catalog_env: catalog.environment }
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
      true
    rescue => detail
      Puppet.log_exception(detail, _("Failed to apply catalog: %{detail}") % { detail: detail })
      return nil
    ensure
      execute_postrun_command or return nil
    end
  ensure
    report.cached_catalog_status ||= @cached_catalog_status
    report.add_times(:total, Time.now - start)
    report.finalize_report
    Puppet::Util::Log.close(report)
    send_report(report)
    Puppet.pop_context
  end
  private :run_internal

  def find_functional_server
    Puppet.settings[:server_list].each do |server|
      host = server[0]
      port = server[1] || Puppet[:masterport]
      begin
        http = Puppet::Network::HttpPool.http_ssl_instance(host, port)
        response = http.get('/status/v1/simple/master')
        return [host, port] if response.is_a?(Net::HTTPOK)

        Puppet.debug(_("Puppet server %{host}:%{port} is unavailable: %{code} %{reason}") %
                     { host: host, port: port, code: response.code, reason: response.message })
      rescue => detail
        #TRANSLATORS 'server_list' is the name of a setting and should not be translated
        Puppet.debug _("Unable to connect to server from server_list setting: %{detail}") % {detail: detail}
      end
    end
    [nil, nil]
  end
  private :find_functional_server

  def send_report(report)
    puts report.summary if Puppet[:summarize]
    save_last_run_summary(report)
    Puppet::Transaction::Report.indirection.save(report, nil, :environment => Puppet::Node::Environment.remote(@environment)) if Puppet[:report]
  rescue => detail
    Puppet.log_exception(detail, _("Could not send report: %{detail}") % { detail: detail })
  end

  def save_last_run_summary(report)
    mode = Puppet.settings.setting(:lastrunfile).mode
    Puppet::Util.replace_file(Puppet[:lastrunfile], mode) do |fh|
      fh.print YAML.dump(report.raw_summary)
    end
  rescue => detail
    Puppet.log_exception(detail, _("Could not save last run local report: %{detail}") % { detail: detail })
  end

  private

  def execute_from_setting(setting)
    return true if (command = Puppet[setting]) == ""

    begin
      Puppet::Util::Execution.execute([command])
      true
    rescue => detail
      Puppet.log_exception(detail, _("Could not run command from %{setting}: %{detail}") % { setting: setting, detail: detail })
      false
    end
  end

  def retrieve_catalog_from_cache(query_options)
    result = nil
    @duration = thinmark do
      result = Puppet::Resource::Catalog.indirection.find(
        Puppet[:node_name_value],
        query_options.merge(
          :ignore_terminus => true,
          :environment     => Puppet::Node::Environment.remote(@environment)
        )
      )
    end
    result
  rescue => detail
    Puppet.log_exception(detail, _("Could not retrieve catalog from cache: %{detail}") % { detail: detail })
    return nil
  end

  def retrieve_new_catalog(query_options)
    result = nil
    @duration = thinmark do
      result = Puppet::Resource::Catalog.indirection.find(
        Puppet[:node_name_value],
        query_options.merge(
          :ignore_cache      => true,
          # We never want to update the cached Catalog if we're running in noop mode.
          :ignore_cache_save => Puppet[:noop],
          :environment       => Puppet::Node::Environment.remote(@environment),
          :fail_on_404       => true
        )
      )
    end
    result
  rescue StandardError => detail
    Puppet.log_exception(detail, _("Could not retrieve catalog from remote server: %{detail}") % { detail: detail })
    return nil
  end

  def download_plugins(remote_environment_for_plugins)
    @handler.download_plugins(remote_environment_for_plugins)
  end
end
