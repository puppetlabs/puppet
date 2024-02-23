# frozen_string_literal: true

require_relative '../../../puppet/environments'
require_relative '../../../puppet/node'
require_relative '../../../puppet/resource/catalog'
require_relative '../../../puppet/indirector/code'
require_relative '../../../puppet/util/profiler'
require_relative '../../../puppet/util/checksums'
require 'yaml'
require 'uri'

class Puppet::Resource::Catalog::Compiler < Puppet::Indirector::Code
  desc "Compiles catalogs on demand using Puppet's compiler."

  include Puppet::Util
  include Puppet::Util::Checksums

  attr_accessor :code

  # @param request [Puppet::Indirector::Request] an indirection request
  #   (possibly) containing facts
  # @return [Puppet::Node::Facts] facts object corresponding to facts in request
  def extract_facts_from_request(request)
    text_facts = request.options[:facts]
    return unless text_facts

    format = request.options[:facts_format]
    unless format
      raise ArgumentError, _("Facts but no fact format provided for %{request}") % { request: request.key }
    end

    Puppet::Util::Profiler.profile(_("Found facts"), [:compiler, :find_facts]) do
      facts = text_facts.is_a?(Puppet::Node::Facts) ? text_facts :
                                                      convert_wire_facts(text_facts, format)

      unless facts.name == request.key
        raise Puppet::Error, _("Catalog for %{request} was requested with fact definition for the wrong node (%{fact_name}).") % { request: request.key.inspect, fact_name: facts.name.inspect }
      end

      return facts
    end
  end

  def save_facts_from_request(facts, request)
    Puppet::Node::Facts.indirection.save(facts, nil,
                                         :environment => request.environment,
                                         :transaction_uuid => request.options[:transaction_uuid])
  end

  # Compile a node's catalog.
  def find(request)
    facts = extract_facts_from_request(request)

    save_facts_from_request(facts, request) unless facts.nil?

    node = node_from_request(facts, request)
    node.trusted_data = Puppet.lookup(:trusted_information) { Puppet::Context::TrustedInformation.local(node) }.to_h

    if node.environment
      # If the requested environment name doesn't match the server specified environment
      # name, as determined by the node terminus, and the request wants us to check for an
      # environment mismatch, then return an empty catalog with the server-specified
      # enviroment.
      if request.remote? && request.options[:check_environment]
        # The "environment" may be same while environment objects differ. This
        # is most likely because the environment cache was flushed between the request
        # processing and node lookup. Environment overrides `==` but requires the
        # name and modulepath to be the same. When using versioned environment dirs the
        # same "environment" can have different modulepaths so simply compare names here.
        if node.environment.name != request.environment.name
          Puppet.warning _("Requested environment '%{request_env}' did not match server specified environment '%{server_env}'") % { request_env: request.environment.name, server_env: node.environment.name }
          return Puppet::Resource::Catalog.new(node.name, node.environment)
        end
      end

      node.environment.with_text_domain do
        envs = Puppet.lookup(:environments)
        envs.guard(node.environment.name)
        begin
          compile(node, request.options)
        ensure
          envs.unguard(node.environment.name)
        end
      end
    else
      compile(node, request.options)
    end
  end

  # filter-out a catalog to remove exported resources
  def filter(catalog)
    return catalog.filter { |r| r.virtual? } if catalog.respond_to?(:filter)

    catalog
  end

  def initialize
    Puppet::Util::Profiler.profile(_("Setup server facts for compiling"), [:compiler, :init_server_facts]) do
      set_server_facts
    end
  end

  # Is our compiler part of a network, or are we just local?
  def networked?
    Puppet.run_mode.server?
  end

  def require_environment?
    false
  end

  private

  # @param facts [String] facts in a wire format for decoding
  # @param format [String] a content-type string
  # @return [Puppet::Node::Facts] facts object deserialized from supplied string
  # @api private
  def convert_wire_facts(facts, format)
    case format
    when 'pson'
      # We unescape here because the corresponding code in Puppet::Configurer::FactHandler encodes with Puppet::Util.uri_query_encode
      # PSON is deprecated, but continue to accept from older agents
      return Puppet::Node::Facts.convert_from('pson', CGI.unescape(facts))
    when 'application/json'
      return Puppet::Node::Facts.convert_from('json', CGI.unescape(facts))
    else
      raise ArgumentError, _("Unsupported facts format")
    end
  end

  # Add any extra data necessary to the node.
  def add_node_data(node)
    # Merge in our server-side facts, so they can be used during compilation.
    node.add_server_facts(@server_facts)
  end

  # Determine which checksum to use; if agent_checksum_type is not nil,
  # use the first entry in it that is also in known_checksum_types.
  # If no match is found, return nil.
  def common_checksum_type(agent_checksum_type)
    if agent_checksum_type
      agent_checksum_types = agent_checksum_type.split('.').map { |type| type.to_sym }
      checksum_type = agent_checksum_types.drop_while do |type|
        not known_checksum_types.include? type
      end.first
    end
    checksum_type
  end

  def get_content_uri(metadata, source, environment_path)
    # The static file content server doesn't know how to expand mountpoints, so
    # we need to do that ourselves from the actual system path of the source file.
    # This does that, while preserving any user-specified server or port.
    source_path = Pathname.new(metadata.full_path)
    path = source_path.relative_path_from(environment_path).to_s
    source_as_uri = URI.parse(Puppet::Util.uri_encode(source))
    server = source_as_uri.host
    port = ":#{source_as_uri.port}" if source_as_uri.port
    return "puppet://#{server}#{port}/#{path}"
  end

  # Helper method to decide if a file resource's metadata can be inlined.
  # Also used to profile/log reasons for not inlining.
  def inlineable?(resource, sources)
    case
    when resource[:ensure] == 'absent'
      # TRANSLATORS Inlining refers to adding additional metadata (in this case we are not inlining)
      return Puppet::Util::Profiler.profile(_("Not inlining absent resource"), [:compiler, :static_compile_inlining, :skipped_file_metadata, :absent]) { false }
    when sources.empty?
      # TRANSLATORS Inlining refers to adding additional metadata (in this case we are not inlining)
      return Puppet::Util::Profiler.profile(_("Not inlining resource without sources"), [:compiler, :static_compile_inlining, :skipped_file_metadata, :no_sources]) { false }
    when (not (sources.all? { |source| source =~ /^puppet:/ }))
      # TRANSLATORS Inlining refers to adding additional metadata (in this case we are not inlining)
      return Puppet::Util::Profiler.profile(_("Not inlining unsupported source scheme"), [:compiler, :static_compile_inlining, :skipped_file_metadata, :unsupported_scheme]) { false }
    else
      return true
    end
  end

  # Return true if metadata is inlineable, meaning the request's source is
  # for the 'modules' mount and the resolved path is of the form:
  #   $codedir/environments/$environment/*/*/files/**
  def inlineable_metadata?(metadata, source, environment_path)
    source_as_uri = URI.parse(Puppet::Util.uri_encode(source))

    location = Puppet::Module::FILETYPES['files']

    !!(source_as_uri.path =~ /^\/modules\// &&
       metadata.full_path =~ /#{environment_path}\/[^\/]+\/[^\/]+\/#{location}\/.+/)
  end

  # Helper method to log file resources that could not be inlined because they
  # fall outside of an environment.
  def log_file_outside_environment
    # TRANSLATORS Inlining refers to adding additional metadata (in this case we are not inlining)
    Puppet::Util::Profiler.profile(_("Not inlining file outside environment"), [:compiler, :static_compile_inlining, :skipped_file_metadata, :file_outside_environment]) { true }
  end

  # Helper method to log file resources that were successfully inlined.
  def log_metadata_inlining
    # TRANSLATORS Inlining refers to adding additional metadata
    Puppet::Util::Profiler.profile(_("Inlining file metadata"), [:compiler, :static_compile_inlining, :inlined_file_metadata]) { true }
  end

  # Inline file metadata for static catalogs
  # Initially restricted to files sourced from codedir via puppet:/// uri.
  def inline_metadata(catalog, checksum_type)
    environment_path = Pathname.new File.join(Puppet[:environmentpath], catalog.environment)
    environment_path = Puppet::Environments::Directories.real_path(environment_path)
    list_of_resources = catalog.resources.find_all { |res| res.type == "File" }

    # TODO: get property/parameter defaults if entries are nil in the resource
    # For now they're hard-coded to match the File type.

    list_of_resources.each do |resource|
      sources = [resource[:source]].flatten.compact
      next unless inlineable?(resource, sources)

      # both need to handle multiple sources
      if resource[:recurse] == true || resource[:recurse] == 'true' || resource[:recurse] == 'remote'
        # Construct a hash mapping sources to arrays (list of files found recursively) of metadata
        options = {
          :environment => catalog.environment_instance,
          :links => resource[:links] ? resource[:links].to_sym : :manage,
          :checksum_type => resource[:checksum] ? resource[:checksum].to_sym : checksum_type.to_sym,
          :source_permissions => resource[:source_permissions] ? resource[:source_permissions].to_sym : :ignore,
          :recurse => true,
          :recurselimit => resource[:recurselimit],
          :max_files => resource[:max_files],
          :ignore => resource[:ignore],
        }

        sources_in_environment = true

        source_to_metadatas = {}
        sources.each do |source|
          source = Puppet::Type.type(:file).attrclass(:source).normalize(source)

          list_of_data = Puppet::FileServing::Metadata.indirection.search(source, options)
          next unless list_of_data

          basedir_meta = list_of_data.find { |meta| meta.relative_path == '.' }
          devfail "FileServing::Metadata search should always return the root search path" if basedir_meta.nil?

          unless inlineable_metadata?(basedir_meta, source, environment_path)
            # If any source is not in the environment path, skip inlining this resource.
            log_file_outside_environment
            sources_in_environment = false
            break
          end

          base_content_uri = get_content_uri(basedir_meta, source, environment_path)
          list_of_data.each do |metadata|
            if metadata.relative_path == '.'
              metadata.content_uri = base_content_uri
            else
              metadata.content_uri = "#{base_content_uri}/#{metadata.relative_path}"
            end
          end

          source_to_metadatas[source] = list_of_data
          # Optimize for returning less data if sourceselect is first
          if resource[:sourceselect] == 'first' || resource[:sourceselect].nil?
            break
          end
        end

        if sources_in_environment && !source_to_metadatas.empty?
          log_metadata_inlining
          catalog.recursive_metadata[resource.title] = source_to_metadatas
        end
      else
        options = {
          :environment => catalog.environment_instance,
          :links => resource[:links] ? resource[:links].to_sym : :manage,
          :checksum_type => resource[:checksum] ? resource[:checksum].to_sym : checksum_type.to_sym,
          :source_permissions => resource[:source_permissions] ? resource[:source_permissions].to_sym : :ignore
        }

        metadata = nil
        sources.each do |source|
          source = Puppet::Type.type(:file).attrclass(:source).normalize(source)

          data = Puppet::FileServing::Metadata.indirection.find(source, options)
          next unless data

          metadata = data
          metadata.source = source
          break
        end

        raise _("Could not get metadata for %{resource}") % { resource: resource[:source] } unless metadata

        if inlineable_metadata?(metadata, metadata.source,  environment_path)
          metadata.content_uri = get_content_uri(metadata, metadata.source, environment_path)
          log_metadata_inlining

          # If the file is in the environment directory, we can safely inline
          catalog.metadata[resource.title] = metadata
        else
          # Log a profiler event that we skipped this file because it is not in an environment.
          log_file_outside_environment
        end
      end
    end
  end

  # Compile the actual catalog.
  def compile(node, options)
    if node.environment && node.environment.static_catalogs? && options[:static_catalog] && options[:code_id]
      # Check for errors before compiling the catalog
      checksum_type = common_checksum_type(options[:checksum_type])
      raise Puppet::Error, _("Unable to find a common checksum type between agent '%{agent_type}' and master '%{master_type}'.") % { agent_type: options[:checksum_type], master_type: known_checksum_types } unless checksum_type
    end

    escaped_node_name = node.name.gsub(/%/, '%%')
    if checksum_type
      if node.environment
        escaped_node_environment = node.environment.to_s.gsub(/%/, '%%')
        benchmark_str = _("Compiled static catalog for %{node} in environment %{environment} in %%{seconds} seconds") % { node: escaped_node_name, environment: escaped_node_environment }
        profile_str   = _("Compiled static catalog for %{node} in environment %{environment}") % { node: node.name, environment: node.environment }
      else
        benchmark_str = _("Compiled static catalog for %{node} in %%{seconds} seconds") % { node: escaped_node_name }
        profile_str   = _("Compiled static catalog for %{node}") % { node: node.name }
      end
    elsif node.environment
      escaped_node_environment = node.environment.to_s.gsub(/%/, '%%')
      benchmark_str = _("Compiled catalog for %{node} in environment %{environment} in %%{seconds} seconds") % { node: escaped_node_name, environment: escaped_node_environment }
      profile_str   = _("Compiled catalog for %{node} in environment %{environment}") % { node: node.name, environment: node.environment }
    else
      benchmark_str = _("Compiled catalog for %{node} in %%{seconds} seconds") % { node: escaped_node_name }
      profile_str   = _("Compiled catalog for %{node}") % { node: node.name }
    end
    config = nil

    benchmark(:notice, benchmark_str) do
      compile_type = checksum_type ? :static_compile : :compile
      Puppet::Util::Profiler.profile(profile_str, [:compiler, compile_type, node.environment, node.name]) do
        begin
          config = Puppet::Parser::Compiler.compile(node, options[:code_id])
        rescue Puppet::Error => detail
          Puppet.err(detail.to_s) if networked?
          raise
        ensure
          Puppet::Type.clear_misses unless Puppet[:always_retry_plugins]
        end

        if checksum_type && config.is_a?(model)
          escaped_node_name = node.name.gsub(/%/, '%%')
          if node.environment
            escaped_node_environment = node.environment.to_s.gsub(/%/, '%%')
            # TRANSLATORS Inlined refers to adding additional metadata
            benchmark_str = _("Inlined resource metadata into static catalog for %{node} in environment %{environment} in %%{seconds} seconds") % { node: escaped_node_name, environment: escaped_node_environment }
            # TRANSLATORS Inlined refers to adding additional metadata
            profile_str   = _("Inlined resource metadata into static catalog for %{node} in environment %{environment}") % { node: node.name, environment: node.environment }
          else
            # TRANSLATORS Inlined refers to adding additional metadata
            benchmark_str = _("Inlined resource metadata into static catalog for %{node} in %%{seconds} seconds") % { node: escaped_node_name }
            # TRANSLATORS Inlined refers to adding additional metadata
            profile_str   = _("Inlined resource metadata into static catalog for %{node}") % { node: node.name }
          end
          benchmark(:notice, benchmark_str) do
            Puppet::Util::Profiler.profile(profile_str, [:compiler, :static_compile_postprocessing, node.environment, node.name]) do
              inline_metadata(config, checksum_type)
            end
          end
        end
      end
    end

    config
  end

  # Use indirection to find the node associated with a given request
  def find_node(name, environment, transaction_uuid, configured_environment, facts)
    Puppet::Util::Profiler.profile(_("Found node information"), [:compiler, :find_node]) do
      node = nil
      begin
        node = Puppet::Node.indirection.find(name, :environment => environment,
                                                   :transaction_uuid => transaction_uuid,
                                                   :configured_environment => configured_environment,
                                                   :facts => facts)
      rescue => detail
        message = _("Failed when searching for node %{name}: %{detail}") % { name: name, detail: detail }
        Puppet.log_exception(detail, message)
        raise Puppet::Error, message, detail.backtrace
      end

      # Add any external data to the node.
      if node
        add_node_data(node)
      end
      node
    end
  end

  # Extract the node from the request, or use the request
  # to find the node.
  def node_from_request(facts, request)
    node = request.options[:use_node]
    if node
      if request.remote?
        raise Puppet::Error, _("Invalid option use_node for a remote request")
      else
        return node
      end
    end

    # We rely on our authorization system to determine whether the connected
    # node is allowed to compile the catalog's node referenced by key.
    # By default the REST authorization system makes sure only the connected node
    # can compile his catalog.
    # This allows for instance monitoring systems or puppet-load to check several
    # node's catalog with only one certificate and a modification to auth.conf
    # If no key is provided we can only compile the currently connected node.
    name = request.key || request.node
    node = find_node(name, request.environment, request.options[:transaction_uuid], request.options[:configured_environment], facts)
    if node
      return node
    end

    raise ArgumentError, _("Could not find node '%{name}'; cannot compile") % { name: name }
  end

  # Initialize our server fact hash; we add these to each client, and they
  # won't change while we're running, so it's safe to cache the values.
  #
  # See also set_server_facts in Puppet::Server::Compiler in puppetserver.
  def set_server_facts
    @server_facts = {}

    # Add our server Puppet Enterprise version, if available.
    pe_version_file = '/opt/puppetlabs/server/pe_version'
    if File.readable?(pe_version_file) and !File.zero?(pe_version_file)
      @server_facts['pe_serverversion'] = File.read(pe_version_file).chomp
    end

    # Add our server version to the fact list
    @server_facts["serverversion"] = Puppet.version.to_s

    # And then add the server name and IP
    { "servername" => "networking.fqdn",
      "serverip" => "networking.ip",
      "serverip6" => "networking.ip6" }.each do |var, fact|
      value = Puppet.runtime[:facter].value(fact)
      unless value.nil?
        @server_facts[var] = value
      end
    end

    if @server_facts["servername"].nil?
      host = Puppet.runtime[:facter].value('networking.hostname')
      if host.nil?
        Puppet.warning _("Could not retrieve fact servername")
      elsif domain = Puppet.runtime[:facter].value('networking.domain') # rubocop:disable Lint/AssignmentInCondition
        @server_facts["servername"] = [host, domain].join(".")
      else
        @server_facts["servername"] = host
      end
    end

    if @server_facts["serverip"].nil? && @server_facts["serverip6"].nil?
      Puppet.warning _("Could not retrieve either serverip or serverip6 fact")
    end
  end
end
