require 'spec_helper'
require 'puppet/rest_client/server_resolution'

describe Puppet::Rest::Resolution do
  context '#select_server_and_port' do
    context 'when not using SRV records' do
      before :each do
        Puppet.settings[:use_srv_records] = false
      end

      it "yields the request with the default server and port when no server or port were specified on the original request" do
        server, port = Puppet::Rest::Resolution.select_server_and_port(srv_service: :puppet, default_server: 'puppet.example.com', default_port: '90210')
        expect(server).to eq('puppet.example.com')
        expect(port).to eq('90210')
      end
    end

    context 'when using SRV records' do
      before :each do
        Puppet.settings[:use_srv_records] = true
        Puppet.settings[:srv_domain]      = 'example.com'
      end

      context "when SRV returns servers" do
        before :each do
          @dns_mock = mock('dns')
          Resolv::DNS.expects(:new).returns(@dns_mock)

          @port = 7205
          @host = '_x-puppet._tcp.example.com'
          @srv_records = [Resolv::DNS::Resource::IN::SRV.new(0, 0, @port, @host)]

          @dns_mock.expects(:getresources).
            with("_x-puppet._tcp.#{Puppet.settings[:srv_domain]}", Resolv::DNS::Resource::IN::SRV).
            returns(@srv_records)
        end

        it "yields a request using the server and port from the SRV record" do
          server, port = Puppet::Rest::Resolution.select_server_and_port
          expect(server).to eq('_x-puppet._tcp.example.com')
          expect(port).to eq(7205)
        end
      end
    end
  end
end
