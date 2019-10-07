require 'puppet/util/json'

class Puppet::Network::HTTP::API::Master::V3::Environments
  def initialize(env_loader)
    @env_loader = env_loader
  end

  def call(request, response)
    response.respond_with(200, "application/json", Puppet::Util::Json.dump({
      "search_paths" => @env_loader.search_paths,
      "environments" => Hash[@env_loader.list.collect do |env|
        [env.name, {
          "settings" => {
            "modulepath" => env.full_modulepath,
            "manifest" => env.manifest,
            "environment_timeout" => timeout(env),
            "config_version" => env.config_version || '',
          }
        }]
      end]
    }))
  end

  private

  def timeout(env)
    ttl = @env_loader.get_conf(env.name).environment_timeout
    if ttl == Float::INFINITY
      "unlimited"
    else
      ttl
    end
  end

end
