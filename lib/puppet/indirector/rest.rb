require 'net/http'
require 'uri'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
    # Figure out the content type, turn that into a format, and use the format
    # to extract the body of the response.
    def deserialize(response)
        # Raise the http error if we didn't get a 'success' of some kind.
        response.error! unless response.code =~ /^2/

        # Convert the response to a deserialized object.
        model.convert_from(response['content-type'], response.body)
    end

    # Provide appropriate headers.
    def headers
        {"Accept" => model.supported_formats.join(", ")}
    end
  
    def network
        Puppet::Network::HttpPool.http_instance(Puppet[:server], Puppet[:masterport].to_i)
    end

    def rest_connection_details
        { :host => Puppet[:server], :port => Puppet[:masterport].to_i }
    end
    
    def find(request)
        deserialize network.get("/#{indirection.name}/#{request.key}", headers)
    end
    
    def search(request)
        if request.key
            path = "/#{indirection.name}/#{request.key}"
        else
            path = "/#{indirection.name}"
        end
        deserialize network.get(path, headers)
    end
    
    def destroy(request)
        deserialize network.delete("/#{indirection.name}/#{request.key}", headers)
    end
    
    def save(request)
        deserialize network.put("/#{indirection.name}/", request.instance.render, headers)
    end
end
