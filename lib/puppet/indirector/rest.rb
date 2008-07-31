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
  
    def network
        Puppet::Network::HttpPool.http_instance(Puppet[:server], Puppet[:masterport].to_i)
    end

    def find(request)
        deserialize network.get("/#{indirection.name}/#{request.key}", headers)
    end
    
    def search(request)
        if request.key
            path = "/#{indirection.name}s/#{request.key}"
        else
            path = "/#{indirection.name}s"
        end
        unless result = deserialize(network.get(path, headers), true)
            return []
        end
        return result
    end
    
    def destroy(request)
        deserialize network.delete("/#{indirection.name}/#{request.key}", headers)
    end
    
    def save(request)
        deserialize network.put("/#{indirection.name}/", request.instance.render, headers)
    end
end
