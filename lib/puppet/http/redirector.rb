#
# @api private
#
# Handle HTTP redirects
#
class Puppet::HTTP::Redirector
  #
  # @api private
  #
  # Create a new redirect handler
  #
  # @param [Integer] redirect_limit maximum number of redirects allowed
  #
  def initialize(redirect_limit)
    @redirect_limit = redirect_limit
  end

  #
  # @api private
  #
  # Determine of the HTTP response code indicates a redirect
  #
  # @param [Net::HTTP] request request that received the response
  # @param [Puppet::HTTP::Response] response
  #
  # @return [Boolean] true if the response code is 301, 302, or 307.
  #
  def redirect?(request, response)
    # Net::HTTPRedirection is not used because historically puppet
    # has only handled these, and we're not a browser
    case response.code
    when 301, 302, 307
      true
    else
      false
    end
  end

  #
  # @api private
  #
  # Implement the HTTP request redirection
  #
  # @param [Net::HTTP] request request that has been redirected
  # @param [Puppet::HTTP::Response] response
  # @param [Integer] redirects the current number of redirects
  #
  # @return [Net::HTTP] A new request based on the original request, but with
  #   the redirected location
  #
  def redirect_to(request, response, redirects)
    raise Puppet::HTTP::TooManyRedirects.new(request.uri) if redirects >= @redirect_limit

    location = parse_location(response)
    url = request.uri.merge(location)

    new_request = request.class.new(url)
    new_request.body = request.body
    request.each do |header, value|
      unless Puppet[:location_trusted]
        # skip adding potentially sensitive header to other hosts
        next if header.casecmp('Authorization').zero? && request.uri.host.casecmp(location.host) != 0
        next if header.casecmp('Cookie').zero? && request.uri.host.casecmp(location.host) != 0
      end
      new_request[header] = value
    end

    # mimic private Net::HTTP#addr_port
    new_request['Host'] = if (location.scheme == 'https' && location.port == 443) ||
                             (location.scheme == 'http' && location.port == 80)
                            location.host
                          else
                            "#{location.host}:#{location.port}"
                          end

    new_request
  end

  private

  def parse_location(response)
    location = response['location']
    raise Puppet::HTTP::ProtocolError.new(_("Location response header is missing")) unless location

    URI.parse(location)
  rescue URI::InvalidURIError => e
    raise Puppet::HTTP::ProtocolError.new(_("Location URI is invalid: %{detail}") % { detail: e.message}, e)
  end
end
