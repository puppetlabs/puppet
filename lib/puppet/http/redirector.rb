class Puppet::HTTP::Redirector
  def initialize(redirect_limit)
    @redirect_limit = redirect_limit
  end

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

  def redirect_to(request, response, redirects)
    raise Puppet::HTTP::TooManyRedirects.new(request.uri) if redirects >= @redirect_limit

    location = parse_location(response)
    if location.relative?
      url = request.uri.dup
      url.path = location.path
    else
      url = location.dup
    end
    url.query = request.uri.query

    new_request = request.class.new(url)
    new_request.body = request.body
    request.each do |header, value|
      new_request[header] = value
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
