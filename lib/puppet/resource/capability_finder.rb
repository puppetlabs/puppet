#
# A helper module to look a capability up from PuppetDB
#
# @todo lutter 2015-03-10: determine whether this should be based on
# Puppet::Pops::Evaluator::Collectors, or at least use
# Puppet::Util::Puppetdb::Http

require 'net/http'
require 'cgi'
require 'json'

# @api private
module Puppet::Resource::CapabilityFinder

  # Looks up a capability resource from PuppetDB. Capability resources are
  # required to be unique per environment and code id. If multiple copies of a
  # capability resource are found, the one matching the current code id is
  # used.
  #
  # @param environment [String] environment name
  # @param code_id [String,nil] code_id of the catalog
  # @param cap [Puppet::Type] the capability resource type instance
  # @return [Puppet::Resource,nil] The found capability resource or `nil` if it could not be found
  def self.find(environment, code_id, cap)
    unless Puppet::Util.const_defined?('Puppetdb')
      raise Puppet::DevError, 'PuppetDB is not available'
    end

    resources = search(environment, nil, cap)

    if resources.size > 1 && code_id
      Puppet.debug "Found multiple resources when looking up capability #{cap}, filtering by code id #{code_id}"
      resources = search(environment, code_id, cap)
    end

    if resources.size > 1
      raise Puppet::DevError,
        "Unexpected response from PuppetDB when looking up #{cap}:\n" \
        "expected exactly one resource but got #{resources.size};\n" \
        "returned data is:\n#{resources.inspect}"
    end

    if resource_hash = resources.first
      instantiate_resource(resource_hash)
    else
      Puppet.debug "Could not find capability resource #{cap} in PuppetDB"
      nil
    end
  end

  def self.search(environment, code_id, cap)
    query_terms = [
      'and',
      ['=', 'type', cap.type.capitalize],
      ['=', 'title', cap.title.to_s],
      ['=', 'tag', "producer:#{environment}"]
    ]

    unless code_id.nil?
      query_terms << ['in', 'certname',
        ['extract', 'certname',
          ['select_catalogs',
            ['=', 'code_id', code_id]]]]
    end

    Puppet.notice "Looking up capability #{cap} in PuppetDB: #{query_terms}"

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
        url = "/pdb/query/v4/resource?query=#{CGI.escape(query.to_json)}"
        response = Puppet::Util::Puppetdb::Http.action(url) do |conn, uri|
          conn.get(uri, { 'Accept' => 'application/json'})
        end
        JSON.parse(response.body)
      end

      # The format of the response body is documented at
      #   http://docs.puppetlabs.com/puppetdb/3.0/api/query/v4/resources.html#response-format
      unless result.is_a?(Array)
        raise Puppet::DevError,
        "Unexpected response from PuppetDB when looking up #{cap}: " \
          "expected an Array but got #{result.inspect}"
      end

      result
    rescue JSON::JSONError => e
      raise Puppet::DevError,
        "Invalid JSON from PuppetDB when looking up #{cap}\n#{e}"
    end
  end

  private

  def self.instantiate_resource(resource_hash)
    resource = Puppet::Resource.new(resource_hash['type'],
                                    resource_hash['title'])
    real_type = Puppet::Type.type(resource.type)
    if real_type.nil?
      fail Puppet::ParseError,
        "Could not find resource type #{resource.type} returned from PuppetDB"
    end
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
end
