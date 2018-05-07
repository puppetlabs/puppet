require 'spec_helper'

require 'puppet/rest/route'

describe Puppet::Rest::Route do
  context '#select_server_and_port' do
    it 'returns the default server and port when provided' do
      route = Puppet::Rest::Route.new(api: '/myapi/v1/',
                                      default_server: 'puppet.example.com',
                                      default_port: 90210)
      route.select_server_and_port
      expect(route.server).to eq('puppet.example.com')
      expect(route.port).to eq(90210)
    end

    it 'caches the result' do
      route = Puppet::Rest::Route.new(api: '/myapi/v1/',
                                      default_server: 'puppet.example.com',
                                      default_port: 90210)
      route.expects(:default_server)
      route.select_server_and_port
      # just return the values in @server and @port without looking
      # at @default_server
      route.expects(:default_server).never
      route.select_server_and_port
    end

    it 'looks up the server and port when defaults are nil' do
      route = Puppet::Rest::Route.new(api: '/myapi/v1/',
                                      default_server: nil,
                                      default_port: nil)
      Puppet.push_context({ :server => 'puppet.example.com' })
      Puppet.push_context({ :serverport => 90210 })
      server, port = route.select_server_and_port
      expect(server).to eq('puppet.example.com')
      expect(port).to eq(90210)
    end
  end

  context '#uri' do
    it 'returns a URI object based on the provided data' do
      route = Puppet::Rest::Route.new(api: '/myapi/v1/',
                                      default_server: 'puppet.example.com',
                                      default_port: 90210)
      expect(route.uri.to_s).to eq('https://puppet.example.com:90210/myapi/v1/')
    end
  end
end
