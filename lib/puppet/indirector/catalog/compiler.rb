require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/code'
require 'puppet/util/profiler'
require 'puppet/util/checksums'
require 'yaml'

class Puppet::Resource::Catalog::Compiler < Puppet::Indirector::Code
  desc "Compiles catalogs on demand using Puppet's compiler."

  include Puppet::Util
  include Puppet::Util::Checksums

  attr_accessor :code

  def extract_facts_from_request(request)
    return unless text_facts = request.options[:facts]
    unless format = request.options[:facts_format]
      raise ArgumentError, "Facts but no fact format provided for #{request.key}"
    end

    Puppet::Util::Profiler.profile("Found facts", [:compiler, :find_facts]) do
      # If the facts were encoded as yaml, then the param reconstitution system
      # in Network::HTTP::Handler will automagically deserialize the value.
      if text_facts.is_a?(Puppet::Node::Facts)
        facts = text_facts
      else
        # We unescape here because the corresponding code in Puppet::Configurer::FactHandler escapes
        facts = Puppet::Node::Facts.convert_from(format, CGI.unescape(text_facts))
      end

      unless facts.name == request.key
        raise Puppet::Error, "Catalog for #{request.key.inspect} was requested with fact definition for the wrong node (#{facts.name.inspect})."
      end

      options = {
        :environment => request.environment,
        :transaction_uuid => request.options[:transaction_uuid],
      }

      Puppet::Node::Facts.indirection.save(facts, nil, options)
    end
  end

  # Compile a node's catalog.
  def find(request)
    extract_facts_from_request(request)

    node = node_from_request(request)
    node.trusted_data = Puppet.lookup(:trusted_information) { Puppet::Context::TrustedInformation.local(node) }.to_h

    if catalog = compile(node, request.options)
      return catalog
    else
      # This shouldn't actually happen; we should either return
      # a config or raise an exception.
      return nil
    end
  end

  # filter-out a catalog to remove exported resources
  def filter(catalog)
    return catalog.filter { |r| r.virtual? } if catalog.respond_to?(:filter)
    catalog
  end

  def initialize
    Puppet::Util::Profiler.profile("Setup server facts for compiling", [:compiler, :init_server_facts]) do
      set_server_facts
    end
  end

  # Is our compiler part of a network, or are we just local?
  def networked?
    Puppet.run_mode.master?
  end

  private

  # Add any extra data necessary to the node.
  def add_node_data(node)
    # Merge in our server-side facts, so they can be used during compilation.
    node.add_server_facts(@server_facts)
  end

  # Rewrite a given file resource with the metadata from a fileserver based file
  def replace_metadata(resource, metadata)
    # TODO: when we stop using to_ral, we'll have to add a case for ensure => <path>
    # implying a link.
    if resource[:links] == "manage" && metadata.ftype == "link"
      resource.delete(:source)
      resource[:target] = metadata.destination
    end

    # Most of the time, ensure should match the returned metadata. Exceptions are when
    # ensure is `present` (it could be anything), or a path (implies creating a link).
    # `to_ral` caused the path case to munge to managing links, so we warn if there's
    # a mismatch that's not `present`.
    if resource[:ensure] != "present" && resource[:ensure] != metadata.ftype
      Puppet.warning "#{resource} expected to create a #{resource[:ensure]}, but its source "+
        "is a #{metadata.ftype}. The source metadata will override the 'ensure' property."
    end

    resource[:ensure] = metadata.ftype

    if metadata.ftype == "file"
      # Since we use the checksum from metadata, it makes sense to pick up the checksum type
      # from the same source. This should never differ, but seems like the most correct
      # expression of intent.
      resource[:checksum_value] = sumdata(metadata.checksum)
      resource[:checksum] = metadata.checksum_type
    end

    case resource[:source_permissions]
    when "use"
      resource[:owner] ||= metadata.owner
      resource[:group] ||= metadata.group
      if resource[:mode].nil?
        mode = metadata.mode
        mode = mode.to_s(8) if mode.is_a?(Numeric)
        resource[:mode] = mode
      end
    when "use_when_creating"
      raise Puppet::Error, "source_permissions => use_when_creating cannot be set when creating static catalogs"
    end
  end

  # Determine which checksum to use; if agent_checksum_type is not nil,
  # use the first entry in it that is also in known_checksum_types.
  # If no match is found, return nil.
  def common_checksum_type(agent_checksum_type)
    if agent_checksum_type
      agent_checksum_types = agent_checksum_type.split('.').map {|type| type.to_sym}
      checksum_type = agent_checksum_types.drop_while do |type|
        not known_checksum_types.include? type
      end.first
    end
    checksum_type
  end

  # Inline file metadata for static catalogs
  # Initially restricted to files sourced from codedir via puppet:/// uri.
  def inline_metadata(catalog, checksum_type)
    environment_path = File.join(Puppet[:environmentpath], catalog.environment, "")
    list_of_resources = catalog.resources.find_all { |res| res.type == "File" }

    list_of_resources.each do |resource|
      next if resource[:ensure] == 'absent'

      next unless source = resource[:source]
      next unless source =~ /^puppet:/

      if checksum_type && resource[:checksum].nil?
        resource[:checksum] = checksum_type
      end

      file = resource.to_ral

      if file.recurse?
        # Skip recurse resources if the static_catalogs_recursion feature is disabled
        next unless Puppet[:static_catalogs_recursion]

        child_resources = file.recurse_remote_metadata.map do |meta|
          # Don't create a new resource for the parent directory
          next if meta.relative_path == "."

          child_resource = Puppet::Resource.new(:file, File.join(file[:path], meta.relative_path))
          child_resource[:source] = meta.source
          replace_metadata(child_resource, meta)

          # Copy parameters from original parent directory
          file.original_parameters.each do |param, value|
            # These should never be passed to our children
            unless [:parent, :ensure, :recurse, :recurselimit, :target, :alias, :source].include? param
              child_resource[param] = value.to_s
            end
          end
          child_resource
        end.compact
        child_resources = Puppet::Type::File.remove_less_specific_files(child_resources, resource[:path] || resource.title, list_of_resources) do |file_resource|
          file_resource[:path] || file_resource.title
        end

        #TODO: Add edge between `child_resource` and its nearest ancestor and
        # add an edge between `child_resource` and all other resources that depend
        # on `file`
        child_resources.each do |child|
          catalog.add_resource(child)
          catalog.add_edge(file, child)
        end
      else
        metadata = file.parameter(:source).metadata
        raise "Could not get metadata for #{resource[:source]}" unless metadata
        if metadata.full_path.start_with? environment_path
          # If the file is in the environment directory, we can safely inline
          replace_metadata(resource, metadata)
        end
      end
    end
  end

  # Compile the actual catalog.
  def compile(node, options)
    if node.environment && node.environment.static_catalogs? && options[:static_catalog] && options[:code_id]
      # Check for errors before compiling the catalog
      checksum_type = common_checksum_type(options[:checksum_type])
      raise Puppet::Error, "Unable to find a common checksum type between agent '#{options[:checksum_type]}' and master '#{known_checksum_types}'." unless checksum_type
    end

    str = "Compiled %s for #{node.name}" % [checksum_type ? 'static catalog' : 'catalog']
    str += " in environment #{node.environment}" if node.environment
    config = nil

    benchmark(:notice, str) do
      Puppet::Util::Profiler.profile(str, [:compiler, :compile, node.environment, node.name]) do
        begin
          config = Puppet::Parser::Compiler.compile(node, options[:code_id])
        rescue Puppet::Error => detail
          Puppet.err(detail.to_s) if networked?
          raise
        end
      end
    end

    if checksum_type && config.is_a?(model)
      str = "Inlined resource metadata into static catalog for #{node.name}"
      str += " in environment #{node.environment}" if node.environment
      benchmark(:notice, str) do
        Puppet::Util::Profiler.profile(str, [:compiler, :static_inline, node.environment, node.name]) do
          inline_metadata(config, checksum_type)
        end
      end
    end

    config
  end

  # Turn our host name into a node object.
  def find_node(name, environment, transaction_uuid, configured_environment)
    Puppet::Util::Profiler.profile("Found node information", [:compiler, :find_node]) do
      node = nil
      begin
        node = Puppet::Node.indirection.find(name, :environment => environment,
                                             :transaction_uuid => transaction_uuid,
                                             :configured_environment => configured_environment)
      rescue => detail
        message = "Failed when searching for node #{name}: #{detail}"
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
  def node_from_request(request)
    if node = request.options[:use_node]
      if request.remote?
        raise Puppet::Error, "Invalid option use_node for a remote request"
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
    if node = find_node(name, request.environment, request.options[:transaction_uuid], request.options[:configured_environment])
      return node
    end

    raise ArgumentError, "Could not find node '#{name}'; cannot compile"
  end

  # Initialize our server fact hash; we add these to each client, and they
  # won't change while we're running, so it's safe to cache the values.
  def set_server_facts
    @server_facts = {}

    # Add our server version to the fact list
    @server_facts["serverversion"] = Puppet.version.to_s

    # And then add the server name and IP
    {"servername" => "fqdn",
      "serverip" => "ipaddress"
    }.each do |var, fact|
      if value = Facter.value(fact)
        @server_facts[var] = value
      else
        Puppet.warning "Could not retrieve fact #{fact}"
      end
    end

    if @server_facts["servername"].nil?
      host = Facter.value(:hostname)
      if domain = Facter.value(:domain)
        @server_facts["servername"] = [host, domain].join(".")
      else
        @server_facts["servername"] = host
      end
    end
  end
end
