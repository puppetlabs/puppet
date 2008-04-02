require 'net/http'
require 'uri'

# Access objects via REST
class Puppet::Indirector::REST < Puppet::Indirector::Terminus
    def network_fetch(path)
        # TODO: url_encode path, set proper server + port
        Net::HTTP.get(URI.parse("http://127.0.0.1:34343/#{path}"))
    end
    
    def find(name, options = {})
      network_result = network_fetch("#{indirection.name}/#{name}")
      raise YAML.load(network_result) if network_result =~ %r{--- !ruby/exception}
      decoded_result = indirection.model.from_yaml(network_result)
    end
    
    def search(key, options = {})
      network_results = network_fetch("#{indirection.name}s/#{key}")
      raise YAML.load(network_results) if network_results =~ %r{--- !ruby/exception}
      decoded_results = YAML.load(network_results.to_s).collect {|result| indirection.model.from_yaml(result) }
    end
end
