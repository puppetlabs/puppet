require 'spec_helper'
require 'puppet/ssl'

describe Puppet::SSL::Validator::CertAuthValidator do
  include_context('SSL certificate fixtures')
  let(:ssl_configuration) do
    Puppet::SSL::Configuration.default
  end

  let(:ssl_host) do
    stub('ssl_host',
         :certificate => stub('cert', :content => nil),
         :key => stub('key', :content => nil))
  end

  let(:ssl_store) { stub('ssl store') }

  subject do
    described_class.new(ssl_configuration,
                        ssl_host)
  end

  before :each do
    ssl_configuration.stubs(:read_file).
      with(Puppet[:localcacert]).
      returns(root_ca_pem)
  end

  describe '#setup_connection' do
    it 'updates the connection for verification and cert authentication' do
      connection = mock('Net::HTTP')
      ssl_configuration.expects(:ssl_store).with().returns(ssl_store)

      connection.expects(:cert_store=).with(ssl_store)
      connection.expects(:ca_file=).with(ssl_configuration.ca_auth_file)
      connection.expects(:cert=).with(ssl_host.certificate.content)
      connection.expects(:key=).with(ssl_host.key.content)
      connection.expects(:verify_callback=).with(subject)
      connection.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      subject.setup_connection(connection)
    end
  end
end
