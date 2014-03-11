require 'json'

class Puppet::Network::HTTP::API::V2::Environments
  def initialize(env_loader)
    @env_loader = env_loader
  end

  def call(request, response)
    response.respond_with(200, "application/json", JSON.dump({
      "search_paths" => @env_loader.search_paths,
      "environments" => Hash[@env_loader.list.collect do |env|
        [env.name, {
          "settings" => {
            "modulepath" => env.full_modulepath,
            "manifest" => env.manifest
          }
        }]
      end]
    }))
  end
end
