require 'openssl'
require 'puppet/ssl/certificate'

class Puppet::Network::HTTP::RackHttpHandler

    def initialize()
    end

    # do something useful with request (a Rack::Request) and use
    # response to fill your Rack::Response
    def process(request, response)
        raise NotImplementedError, "Your RackHttpHandler subclass is supposed to override service(request)"
    end

    def ssl_client_header(request)
        env_or_request_env(Puppet[:ssl_client_header], request)
    end

    def ssl_client_verify_header(request)
        env_or_request_env(Puppet[:ssl_client_verify_header], request)
    end

    # Older Passenger versions passed all Environment vars in app(env),
    # but since 2.2.3 they (some?) are really in ENV.
    # Mongrel, etc. may also still use request.env.
    def env_or_request_env(var, request)
        if ENV.include?(var)
            ENV[var]
        else
            request.env[var]
        end
    end
end

