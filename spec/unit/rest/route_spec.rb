require 'spec_helper'

require 'puppet/rest/route'

describe Puppet::Rest::Route do
  describe '#with_base_url'do
    let(:dns_resolver) { double('dns resolver') }

    context 'when not using SRV records' do
      before :each do
        Puppet.settings[:use_srv_records] = false
      end

      it "yields a base URL with the values from the specified settings" do
        Puppet[:ca_server] = 'testserver'
        Puppet[:ca_port] = 555
        ca_route = Puppet::Rest::Route.new(api: '/fakeapi/v1/',
                                           server_setting: :ca_server,
                                           port_setting: :ca_port,
                                           srv_service: :test_service)
        count = 0
        rval = ca_route.with_base_url(dns_resolver) do |url|
          count += 1
          expect(url.to_s).to eq('https://testserver:555/fakeapi/v1/')
          'Block return value'
        end
        expect(count).to eq(1)
        expect(rval).to eq('Block return value')
      end

      it "yields a base URL with Puppet's configured server and port when no defaults are specified" do
        Puppet[:server] = 'configured.net'
        Puppet[:masterport] = 8140
        fallback_route = Puppet::Rest::Route.new(api: '/fakeapi/v1/')
        count = 0
        rval = fallback_route.with_base_url(dns_resolver) do |url|
          count += 1
          expect(url.to_s).to eq('https://configured.net:8140/fakeapi/v1/')
          'Block return value'
        end
        expect(count).to eq(1)
        expect(rval).to eq('Block return value')
      end

      it 'yields the first entry in the server list when server_list is in use' do
        Puppet[:server_list] = [['one.net', 111], ['two.net', 222]]
        fallback_route = Puppet::Rest::Route.new(api: '/fakeapi/v1/')
        count = 0
        rval = fallback_route.with_base_url(dns_resolver) do |url|
          count += 1
          expect(url.to_s).to eq('https://one.net:111/fakeapi/v1/')
          'Block return value'
        end
        expect(count).to eq(1)
        expect(rval).to eq('Block return value')
      end

      it 'falls back to :server and :masterport if nil is passed' do
        Puppet[:server] = 'one.net'
        Puppet[:masterport] = 111
        nil_route = Puppet::Rest::Route.new(api: '/fakeapi/v1/',
                                            server_setting: nil,
                                            port_setting: nil)
        count = 0
        rval = nil_route.with_base_url(dns_resolver) do |url|
          count += 1
          expect(url.to_s).to eq('https://one.net:111/fakeapi/v1/')
          'Block return value'
        end
        expect(count).to eq(1)
        expect(rval).to eq('Block return value')
      end
    end

    context 'when using SRV records' do
      context "when SRV returns servers" do
        let(:route) { Puppet::Rest::Route.new(api: '/fakeapi/v1/',
                                              srv_service: :test_service) }

        before :each do
          Puppet.settings[:use_srv_records] = true
          Puppet.settings[:srv_domain]      = 'example.com'

          @dns_mock = double('dns')
          expect(Resolv::DNS).to receive(:new).and_return(@dns_mock)

          @port = 7502
          @target = 'example.com'
          record = Resolv::DNS::Resource::IN::SRV.new(0, 0, @port, @target)
          record.instance_variable_set(:@ttl, 10)
          @srv_records = [record]

          expect(@dns_mock).to receive(:getresources).
            with("_x-puppet-test_service._tcp.example.com", Resolv::DNS::Resource::IN::SRV).
            and_return(@srv_records)
        end

        it "yields a URL using the server and port from the SRV record" do
          count = 0
          rval = route.with_base_url(Puppet::Network::Resolver.new) do |url|
            count += 1
            expect(url.to_s).to eq('https://example.com:7502/fakeapi/v1/')
            'Block return value'
          end
          expect(count).to eq(1)

          expect(rval).to eq('Block return value')
        end

        it "should fall back to the default server when the block raises a SystemCallError" do
          Puppet[:server] = "testserver"
          Puppet[:masterport] = 555

          count = 0
          rval = route.with_base_url(Puppet::Network::Resolver.new) do |url|
            count += 1
            if url.to_s =~ /example.com/ then
              raise SystemCallError, "example failure"
            else
              expect(url.to_s).to eq('https://testserver:555/fakeapi/v1/')
            end

            'Block return value'
          end

          expect(count).to eq(2)
          expect(rval).to eq('Block return value')
        end
      end
    end
  end
end
