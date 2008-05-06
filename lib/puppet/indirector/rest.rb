require 'net/http'
require 'uri'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
    def rest_connection_details
        { :host => Puppet[:server], :port => Puppet[:masterport].to_i }
    end

    def network_fetch(path)
        network.get("/#{path}").body
    end
    
    def network_delete(path)
        network.delete("/#{path}").body
    end
    
    def network_put(path, data)
        network.put("/#{path}", data).body
    end
    
    def find(request)
        network_result = network_fetch("#{indirection.name}/#{request.key}")
        raise YAML.load(network_result) if exception?(network_result)
        indirection.model.from_yaml(network_result)
    end
    
    def search(request)
        network_results = network_fetch("#{indirection.name}s/#{request.key}")
        raise YAML.load(network_results) if exception?(network_results)
        YAML.load(network_results.to_s).collect {|result| indirection.model.from_yaml(result) }
    end
    
    def destroy(request)
        network_result = network_delete("#{indirection.name}/#{request.key}")
        raise YAML.load(network_result) if exception?(network_result)
        YAML.load(network_result.to_s)      
    end
    
    def save(request)
        network_result = network_put("#{indirection.name}/", request.instance.to_yaml)
        raise YAML.load(network_result) if exception?(network_result)
        indirection.model.from_yaml(network_result)
    end
    
  private
  
    def network
        Puppet::Network::HttpPool.http_instance(rest_connection_details[:host], rest_connection_details[:port])
    end
  
    def exception?(yaml_string)
        yaml_string =~ %r{--- !ruby/exception}
    end
end
