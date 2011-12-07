require 'puppet/network/http/api'

module Puppet::Network::HTTP::API::V1
  # How we map http methods and the indirection name in the URI
  # to an indirection method.
  METHOD_MAP = {
    "GET" => {
      :plural => :search,
      :singular => :find
    },
    "POST" => {
      :singular => :find,
    },
    "PUT" => {
      :singular => :save
    },
    "DELETE" => {
      :singular => :destroy
    },
    "HEAD" => {
      :singular => :head
    }
  }

  def uri2indirection(http_method, uri, params)
    environment, indirection, key = uri.split("/", 4)[1..-1] # the first field is always nil because of the leading slash

    raise ArgumentError, "The environment must be purely alphanumeric, not '#{environment}'" unless environment =~ /^\w+$/
    raise ArgumentError, "The indirection name must be purely alphanumeric, not '#{indirection}'" unless indirection =~ /^\w+$/

    method = indirection_method(http_method, indirection)

    params[:environment] = Puppet::Node::Environment.new(environment)

    raise ArgumentError, "No request key specified in #{uri}" if key == "" or key.nil?

    key = URI.unescape(key)

    [indirection, method, key, params]
  end

  def indirection2uri(request)
    indirection = request.method == :search ? pluralize(request.indirection_name.to_s) : request.indirection_name.to_s
    "/#{request.environment.to_s}/#{indirection}/#{request.escaped_key}#{request.query_string}"
  end

  def request_to_uri_and_body(request)
    indirection = request.method == :search ? pluralize(request.indirection_name.to_s) : request.indirection_name.to_s
    ["/#{request.environment.to_s}/#{indirection}/#{request.escaped_key}", request.query_string.sub(/^\?/,'')]
  end

  def indirection_method(http_method, indirection)
    raise ArgumentError, "No support for http method #{http_method}" unless METHOD_MAP[http_method]

    unless method = METHOD_MAP[http_method][plurality(indirection)]
      raise ArgumentError, "No support for plural #{http_method} operations"
    end

    method
  end

  def pluralize(indirection)
    return(indirection == "status" ? "statuses" : indirection + "s")
  end

  def plurality(indirection)
    # NOTE This specific hook for facts is ridiculous, but it's a *many*-line
    # fix to not need this, and our goal is to move away from the complication
    # that leads to the fix being too long.
    return :singular if indirection == "facts"
    return :singular if indirection == "status"
    return :singular if indirection == "certificate_status"
    return :plural if indirection == "inventory"

    result = (indirection =~ /s$|_search$/) ? :plural : :singular

    indirection.sub!(/s$|_search$/, '')
    indirection.sub!(/statuse$/, 'status')

    result
  end
end
