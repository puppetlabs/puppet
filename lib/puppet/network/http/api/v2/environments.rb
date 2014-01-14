require 'json'

class Puppet::Network::HTTP::API::V2::Environments
  def initialize(env_loader)
    @env_loader = env_loader
  end

  def call(request, response)
    response.respond_with(200, "application/json", JSON.dump({
      "search_path" => @env_loader.search_paths,
      "environments" => Hash[@env_loader.list.collect do |env|
        [env.name, {
          "modules" => Hash[env.modules.collect do |mod|
            [mod.name, {
              "version" => mod.version
            }]
          end]
        }]
      end]
    }))
  end
end
