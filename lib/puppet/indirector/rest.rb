require 'net/http'
require 'uri'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
    # Figure out the content type, turn that into a format, and use the format
    # to extract the body of the response.
    def deserialize(response, multiple = false)
        case response.code
        when "404"
            return nil
        when /^2/
            unless response['content-type']
                raise "No content type in http response; cannot parse"
            end

            # Convert the response to a deserialized object.
            if multiple
                model.convert_from_multiple(response['content-type'], response.body)
            else
                model.convert_from(response['content-type'], response.body)
            end
        else
            # Raise the http error if we didn't get a 'success' of some kind.
            message = "Server returned %s: %s" % [response.code, response.message]
            raise Net::HTTPError.new(message, response)
        end
    end

    # Provide appropriate headers.
    def headers
        {"Accept" => model.supported_formats.join(", ")}
    end
  
    def network(request)
        if request.key =~ /^\w+:\/\// # it looks like a URI
            begin
                uri = URI.parse(URI.escape(request.key))
            rescue => detail
                raise ArgumentError, "Could not understand URL %s: %s" % [source, detail.to_s]
            end
            server = uri.host || Puppet[:server]
            port = uri.port.to_i == 0 ? Puppet[:masterport].to_i : uri.port.to_i
        else
            server = Puppet[:server]
            port = Puppet[:masterport].to_i
        end

        Puppet::Network::HttpPool.http_instance(server, port)
    end

    def find(request)
        deserialize network(request).get("/#{indirection.name}/#{request.key}#{query_string(request)}", headers)
    end
    
    def search(request)
        if request.key
            path = "/#{indirection.name}s/#{request.key}#{query_string(request)}"
        else
            path = "/#{indirection.name}s#{query_string(request)}"
        end
        unless result = deserialize(network(request).get(path, headers), true)
            return []
        end
        return result
    end
    
    def destroy(request)
        raise ArgumentError, "DELETE does not accept options" unless request.options.empty?
        deserialize network(request).delete("/#{indirection.name}/#{request.key}", headers)
    end
    
    def save(request)
        raise ArgumentError, "PUT does not accept options" unless request.options.empty?
        deserialize network(request).put("/#{indirection.name}/", request.instance.render, headers)
    end

    private

    # Create the qurey string, if options are present.
    def query_string(request)
        return "" unless request.options and ! request.options.empty?
        "?" + request.options.collect { |key, value| "%s=%s" % [key, value] }.join("&")
    end
end
