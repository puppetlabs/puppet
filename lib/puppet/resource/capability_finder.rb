#
# A helper module to look a capability up from PuppetDB
#
# @todo lutter 2015-03-10: determine whether this should be based on
# Puppet::Pops::Evaluator::Collectors, or at least use
# Puppet::Util::Puppetdb::Http

require 'net/http'
require 'cgi'
require 'puppet/util/json'

# @api private
module Puppet::Resource::CapabilityFinder

  # Looks up a capability resource from PuppetDB. Capability resources are
  # required to be unique per environment and code id. If multiple copies of a
  # capability resource are found, the one matching the current code id is
  # used.
  #
  # @param environment [String] environment name
  # @param code_id [String,nil] code_id of the catalog
  # @param cap [Puppet::Resource] the capability resource type instance
  # @return [Puppet::Resource,nil] The found capability resource or `nil` if it could not be found
  def self.find(environment, code_id, cap)
    unless Puppet::Util.const_defined?('Puppetdb')
      #TRANSLATOR PuppetDB is a product name and should not be translated
      raise Puppet::DevError, _('PuppetDB is not available')
    end

    resources = search(nil, nil, cap)

    if resources.size > 1
      Puppet.debug "Found multiple resources when looking up capability #{cap}, filtering by environment #{environment}"
      resources = resources.select { |r| r['tags'].any? { |t| t == "producer:#{environment}" } }
    end

    if resources.empty?
      Puppet.debug "Could not find capability resource #{cap} in PuppetDB"
    elsif resources.size == 1
      resource_hash = resources.first
    elsif code_id_resource = disambiguate_by_code_id(environment, code_id, cap)
      resource_hash = code_id_resource
    else
      #TRANSLATOR PuppetDB is a product name and should not be translated
      message = _("Unexpected response from PuppetDB when looking up %{capability}:") % { capability: cap }
      message += "\n" + _("expected exactly one resource but got %{count};") % { count: resources.size }
      message += "\n" + _("returned data is:\n%{resources}") % { resources: resources.inspect }
      raise Puppet::DevError, message
    end

    if resource_hash
      resource_hash['type'] = cap.resource_type
      instantiate_resource(resource_hash)
    end
  end

  def self.search(environment, code_id, cap)
    query_terms = [
      'and',
      ['=', 'type', cap.type.capitalize],
      ['=', 'title', cap.title.to_s],
    ]

    if environment.nil?
      query_terms << ['~', 'tag', "^producer:"]
    else
      query_terms << ['=', 'tag', "producer:#{environment}"]
    end

    unless code_id.nil?
      query_terms << ['in', 'certname',
        ['extract', 'certname',
          ['select_catalogs',
            ['=', 'code_id', code_id]]]]
    end

    #TRANSLATOR PuppetDB is a product name and should not be translated
    Puppet.notice _("Looking up capability %{capability} in PuppetDB: %{query_terms}") % { capability: cap, query_terms: query_terms }

    query_puppetdb(query_terms)
  end

  def self.query_puppetdb(query)
    begin
      # If using PuppetDB >= 4, use the API method query_puppetdb()
      result = if Puppet::Util::Puppetdb.respond_to?(:query_puppetdb)
        # PuppetDB 4 uses a unified query endpoint, so we have to specify what we're querying
        Puppet::Util::Puppetdb.query_puppetdb(["from", "resources", query])
      # For PuppetDB < 4, use the old internal method action()
      else
        url = "/pdb/query/v4/resource?query=#{Puppet::Util.uri_query_encode(query.to_json)}"
        response = Puppet::Util::Puppetdb::Http.action(url) do |conn, uri|
          conn.get(uri, { 'Accept' => 'application/json'})
        end
        Puppet::Util::Json.load(response.body)
      end

      # The format of the response body is documented at
      #   https://docs.puppetlabs.com/puppetdb/3.0/api/query/v4/resources.html#response-format
      unless result.is_a?(Array)
        #TRANSLATOR PuppetDB is a product name and should not be translated
        raise Puppet::DevError, _("Unexpected response from PuppetDB when looking up %{capability}: expected an Array but got %{result}") %
            { capability: cap, result: result.inspect }
      end

      result
    rescue Puppet::Util::Json::ParseError => e
      #TRANSLATOR PuppetDB is a product name and should not be translated
      raise Puppet::DevError, _("Invalid JSON from PuppetDB when looking up %{capability}\n%{detail}") % { capability: cap, detail: e }
    end
  end

  # Find a distinct copy of the given capability resource by searching for only
  # resources matching the given code_id. Returns `nil` if no code_id is
  # supplied or if there isn't exactly one matching resource.
  #
  # @param environment [String] environment name
  # @param code_id [String,nil] code_id of the catalog
  # @param cap [Puppet::Resource] the capability resource type instance
  def self.disambiguate_by_code_id(environment, code_id, cap)
    if code_id
      Puppet.debug "Found multiple resources when looking up capability #{cap}, filtering by code id #{code_id}"
      resources = search(environment, code_id, cap)

      if resources.size > 1
        Puppet.debug "Found multiple resources matching code id #{code_id} when looking up #{cap}"
        nil
      else
        resources.first
      end
    end
  end
  private_class_method :disambiguate_by_code_id

  def self.instantiate_resource(resource_hash)
    real_type = resource_hash['type']
    resource = Puppet::Resource.new(real_type, resource_hash['title'])
    real_type.parameters.each do |param|
      param = param.to_s
      next if param == 'name'
      if value = resource_hash['parameters'][param]
        resource[param] = value
      else
        Puppet.debug "No capability value for #{resource}->#{param}"
      end
    end
    return resource
  end
  private_class_method :instantiate_resource
end
