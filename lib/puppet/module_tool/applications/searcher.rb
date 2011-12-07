module Puppet::Module::Tool
  module Applications
    class Searcher < Application

      def initialize(term, options = {})
        @term = term
        super(options)
      end

      def run
        request = Net::HTTP::Get.new("/modules.json?q=#{URI.escape(@term)}")
        response = repository.make_http_request(request)
        case response
        when Net::HTTPOK
          matches = PSON.parse(response.body)
        else
          raise RuntimeError, "Could not execute search (HTTP #{response.code})"
          matches = []
        end

        # Return a list of module metadata hashes that match the search query.
        # This return value is used by the module_tool face install search,
        # and displayed to on the console.
        #
        # Example return value:
        #
        # [
        #   {
        #     "name"        => "nginx",
        #     "project_url" => "http://github.com/puppetlabs/puppetlabs-nginx",
        #     "version"     => "0.0.1",
        #     "full_name"   => "puppetlabs/nginx" # full_name comes back from
        #   }                                     # API all to the forge.
        # ]
        #
        matches
      end
    end
  end
end
