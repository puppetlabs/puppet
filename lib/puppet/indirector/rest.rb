require 'net/http'
require 'uri'
require 'puppet/util/json'
require 'semantic_puppet'

require 'puppet/network/http'
require 'puppet/network/http_pool'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
  include Puppet::Network::HTTP::Compression.module

  IndirectedRoutes = Puppet::Network::HTTP::API::IndirectedRoutes
  EXCLUDED_FORMATS = [:yaml, :b64_zlib_yaml, :dot]

  # puppet major version where JSON is enabled by default
  MAJOR_VERSION_JSON_DEFAULT = 5

  class << self
    attr_reader :server_setting, :port_setting
  end

  # Specify the setting that we should use to get the server name.
  def self.use_server_setting(setting)
    @server_setting = setting
  end

  # Specify the setting that we should use to get the port.
  def self.use_port_setting(setting)
    @port_setting = setting
  end

  # Specify the service to use when doing SRV record lookup
  def self.use_srv_service(service)
    @srv_service = service
  end

  def self.srv_service
    @srv_service || :puppet
  end

  # The logic for server and port is kind of gross. In summary:
  # IF an endpoint-specific setting is requested AND that setting has been set by the user
  #    Use that setting.
  #         The defaults for these settings are the "normal" server/masterport settings, so
  #         when they are unset we instead want to "fall back" to the failover-selected
  #         host/port pair.
  # ELSE IF we have a failover-selected host/port
  #    Use what the failover logic came up with
  # ELSE IF the server_list setting is in use
  #    Use the first entry - failover hasn't happened yet, but that
  #    setting is still authoritative
  # ELSE
  #    Go for the legacy server/masterport settings, and hope for the best
  def self.server
    setting = server_setting()
    if setting && setting != :server && Puppet.settings.set_by_config?(setting)
      Puppet.settings[setting]
    else
      server = Puppet.lookup(:server) do
        if primary_server = Puppet.settings[:server_list][0]
          Puppet.debug "Dynamically-bound server lookup failed; using first entry"
          primary_server[0]
        else
          setting ||= :server
          Puppet.debug "Dynamically-bound server lookup failed, falling back to #{setting} setting"
          Puppet.settings[setting]
        end
      end
      server
    end
  end

  # For port there's a little bit of an extra snag: setting a specific
  # server setting and relying on the default port for that server is
  # common, so we also want to check if the assocaited SERVER setting
  # has been set by the user. If either of those are set we ignore the
  # failover-selected port.
  def self.port
    setting = port_setting()
    srv_setting = server_setting()
    if (setting && setting != :masterport && Puppet.settings.set_by_config?(setting)) ||
       (srv_setting && srv_setting != :server && Puppet.settings.set_by_config?(srv_setting))
      Puppet.settings[setting].to_i
    else
      port = Puppet.lookup(:serverport) do
        if primary_server = Puppet.settings[:server_list][0]
          Puppet.debug "Dynamically-bound port lookup failed; using first entry"

          # Port might not be set, so we want to fallback in that
          # case. We know we don't need to use `setting` here, since
          # the default value of every port setting is `masterport`
          (primary_server[1] || Puppet.settings[:masterport])
        else
          setting ||= :masterport
          Puppet.debug "Dynamically-bound port lookup failed; falling back to #{setting} setting"
          Puppet.settings[setting]
        end
      end
      port.to_i
    end
  end

  # Provide appropriate headers.
  def headers
    # yaml is not allowed on the network
    network_formats = model.supported_formats - EXCLUDED_FORMATS
    mime_types = network_formats.map { |f| model.get_format(f).mime }
    common_headers = {
      "Accept"                                     => mime_types.join(', '),
      Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version
    }

    add_accept_encoding(common_headers)
  end

  def add_profiling_header(headers)
    if (Puppet[:profile])
      headers[Puppet::Network::HTTP::HEADER_ENABLE_PROFILING] = "true"
    end
    headers
  end

  def network(request)
    Puppet::Network::HttpPool.http_instance(request.server || self.class.server,
                                            request.port || self.class.port)
  end

  def http_get(request, path, headers = nil, *args)
    http_request(:get, request, path, add_profiling_header(headers), *args)
  end

  def http_post(request, path, data, headers = nil, *args)
    http_request(:post, request, path, data, add_profiling_header(headers), *args)
  end

  def http_head(request, path, headers = nil, *args)
    http_request(:head, request, path, add_profiling_header(headers), *args)
  end

  def http_delete(request, path, headers = nil, *args)
    http_request(:delete, request, path, add_profiling_header(headers), *args)
  end

  def http_put(request, path, data, headers = nil, *args)
    http_request(:put, request, path, data, add_profiling_header(headers), *args)
  end

  def http_request(method, request, *args)
    conn = network(request)
    conn.send(method, *args)
  end

  def find(request)
    uri, body = IndirectedRoutes.request_to_uri_and_body(request)
    uri_with_query_string = "#{uri}?#{body}"

    response = do_request(request) do |req|
      # WEBrick in Ruby 1.9.1 only supports up to 1024 character lines in an HTTP request
      # http://redmine.ruby-lang.org/issues/show/3991
      if "GET #{uri_with_query_string} HTTP/1.1\r\n".length > 1024
        uri_with_env = "#{uri}?environment=#{request.environment.name}"
        http_post(req, uri_with_env, body, headers)
      else
        http_get(req, uri_with_query_string, headers)
      end
    end

    if is_http_200?(response)
      content_type, body = parse_response(response)
      result = deserialize_find(content_type, body)
      result.name = request.key if result.respond_to?(:name=)
      result

    elsif is_http_404?(response)
      return nil unless request.options[:fail_on_404]

      # 404 can get special treatment as the indirector API can not produce a meaningful
      # reason to why something is not found - it may not be the thing the user is
      # expecting to find that is missing, but something else (like the environment).
      # While this way of handling the issue is not perfect, there is at least an error
      # that makes a user aware of the reason for the failure.
      #
      _, body = parse_response(response)
      msg = _("Find %{uri} resulted in 404 with the message: %{body}") % { uri: elide(uri_with_query_string, 100), body: body }
      raise Puppet::Error, msg
    else
      nil
    end
  end

  def head(request)
    response = do_request(request) do |req|
      http_head(req, IndirectedRoutes.request_to_uri(req), headers)
    end

    if is_http_200?(response)
      true
    else
      false
    end
  end

  def search(request)
    response = do_request(request) do |req|
      http_get(req, IndirectedRoutes.request_to_uri(req), headers)
    end

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_search(content_type, body) || []
    else
      []
    end
  end

  def destroy(request)
    raise ArgumentError, _("DELETE does not accept options") unless request.options.empty?

    response = do_request(request) do |req|
      http_delete(req, IndirectedRoutes.request_to_uri(req), headers)
    end

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_destroy(content_type, body)
    else
      nil
    end
  end

  def save(request)
    raise ArgumentError, _("PUT does not accept options") unless request.options.empty?

    response = do_request(request) do |req|
      http_put(req, IndirectedRoutes.request_to_uri(req), req.instance.render, headers.merge({ "Content-Type" => req.instance.mime }))
    end

    if is_http_200?(response)
      content_type, body = parse_response(response)
      deserialize_save(content_type, body)
    else
      nil
    end
  end

  # Encapsulate call to request.do_request with the arguments from this class
  # Then yield to the code block that was called in
  # We certainly could have retained the full request.do_request(...) { |r| ... }
  # but this makes the code much cleaner and we only then actually make the call
  # to request.do_request from here, thus if we change what we pass or how we
  # get it, we only need to change it here.
  def do_request(request)
    response = request.do_request(self.class.srv_service, self.class.server, self.class.port) { |req| yield(req) }

    handle_response(request, response) if response

    response
  end

  def handle_response(request, response)
    server_version = response[Puppet::Network::HTTP::HEADER_PUPPET_VERSION]
    if server_version
      Puppet.lookup(:server_agent_version) do
        Puppet.push_context(:server_agent_version => server_version)
      end
      if SemanticPuppet::Version.parse(server_version).major < MAJOR_VERSION_JSON_DEFAULT &&
          Puppet[:preferred_serialization_format] != 'pson'
        #TRANSLATORS "PSON" should not be translated
        Puppet.warning(_("Downgrading to PSON for future requests"))
        Puppet[:preferred_serialization_format] = 'pson'
      end
    end
  end

  def validate_key(request)
    # Validation happens on the remote end
  end

  private

  def is_http_200?(response)
    case response.code
    when "404"
      false
    when /^2/
      true
    else
      # Raise the http error if we didn't get a 'success' of some kind.
      raise convert_to_http_error(response)
    end
  end

  def is_http_404?(response)
    response.code == "404"
  end

  def convert_to_http_error(response)
    if response.body.to_s.empty? && response.respond_to?(:message)
      returned_message = response.message
    elsif response['content-type'].is_a?(String)
      content_type, body = parse_response(response)
      if content_type =~ /[pj]son/
        returned_message = Puppet::Util::Json.load(body)["message"]
      else
        returned_message = uncompress_body(response)
      end
    else
      returned_message = uncompress_body(response)
    end

    message = _("Error %{code} on SERVER: %{returned_message}") % { code: response.code, returned_message: returned_message }
    Net::HTTPError.new(message, response)
  end

  # Returns the content_type, stripping any appended charset, and the
  # body, decompressed if necessary (content-encoding is checked inside
  # uncompress_body)
  def parse_response(response)
    if response['content-type']
      [ response['content-type'].gsub(/\s*;.*$/,''), uncompress_body(response) ]
    else
      raise _("No content type in http response; cannot parse")
    end
  end

  def deserialize_find(content_type, body)
    model.convert_from(content_type, body)
  end

  def deserialize_search(content_type, body)
    model.convert_from_multiple(content_type, body)
  end

  def deserialize_destroy(content_type, body)
    model.convert_from(content_type, body)
  end

  def deserialize_save(content_type, body)
    nil
  end

  def elide(string, length)
    if Puppet::Util::Log.level == :debug || string.length <= length
      string
    else
      string[0, length - 3] + "..."
    end
  end
end
