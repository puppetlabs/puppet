require 'puppet/network/http/api'

module Puppet::Network::HTTP::API::V1
    # How we map http methods and the indirection name in the URI
    # to an indirection method.
    METHOD_MAP = {
        "GET" => {
            :plural => :search,
            :singular => :find
        },
        "PUT" => {
            :singular => :save
        },
        "DELETE" => {
            :singular => :destroy
        }
    }

    def uri2indirection(http_method, uri, params)
        environment, indirection, key = uri.split("/", 4)[1..-1] # the first field is always nil because of the leading slash

        raise ArgumentError, "The environment must be purely alphanumeric, not '%s'" % environment unless environment =~ /^\w+$/
        raise ArgumentError, "The indirection name must be purely alphanumeric, not '%s'" % indirection unless indirection =~ /^\w+$/

        method = indirection_method(http_method, indirection)

        params[:environment] = environment

        raise ArgumentError, "No request key specified in %s" % uri if key == "" or key.nil?

        key = URI.unescape(key)

        Puppet::Indirector::Request.new(indirection, method, key, params)
    end

    def indirection2uri(request)
        indirection = request.method == :search ? request.indirection_name.to_s + "s" : request.indirection_name.to_s
        "/#{request.environment.to_s}/#{indirection}/#{request.escaped_key}#{request.query_string}"
    end

    def indirection_method(http_method, indirection)
        unless METHOD_MAP[http_method]
            raise ArgumentError, "No support for http method %s" % http_method
        end

        unless method = METHOD_MAP[http_method][plurality(indirection)]
            raise ArgumentError, "No support for plural %s operations" % http_method
        end

        return method
    end

    def plurality(indirection)
        # NOTE This specific hook for facts is ridiculous, but it's a *many*-line
        # fix to not need this, and our goal is to move away from the complication
        # that leads to the fix being too long.
        return :singular if indirection == "facts"

        result = (indirection =~ /s$/) ? :plural : :singular

        indirection.sub!(/s$/, '') if result

        result
    end
end
