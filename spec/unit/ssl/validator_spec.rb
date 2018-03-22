require 'spec_helper'
require 'puppet/ssl'
require 'puppet_spec/ssl'

describe Puppet::SSL::Validator::DefaultValidator, unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files
  let(:ssl_context) do
    mock('OpenSSL::X509::StoreContext')
  end

  before(:all) do
    @pki = PuppetSpec::SSL.create_chained_pki
  end

  let(:ca_path) do
    Puppet[:ssl_client_ca_auth] || Puppet[:localcacert]
  end

  let(:ssl_host) do
    stub('ssl_host',
         :ssl_store => nil,
         :certificate => stub('cert', :content => nil),
         :key => stub('key', :content => nil))
  end

  subject do
    described_class.new(ca_path)
  end

  before :each do
    subject.stubs(:read_file).returns(@pki[:root_cert].to_s)
  end

  describe '#call' do
    before :each do
      ssl_context.stubs(:current_cert).returns(*cert_chain_in_callback_order)
      ssl_context.stubs(:chain).returns(cert_chain)
    end

    context 'When pre-verification is not OK' do
      context 'and the ssl_context is in an error state' do
        let(:root_subject) { @pki[:root_cert].subject.to_s }
        let(:code) { OpenSSL::X509::V_ERR_INVALID_CA }

        it 'rejects the connection' do
          ssl_context.stubs(:error_string).returns("Something went wrong")
          ssl_context.stubs(:error).returns(code)

          expect(subject.call(false, ssl_context)).to eq(false)
        end

        it 'makes the error available via #verify_errors' do
          ssl_context.stubs(:error_string).returns("Something went wrong")
          ssl_context.stubs(:error).returns(code)

          subject.call(false, ssl_context)
          expect(subject.verify_errors).to eq(["Something went wrong for #{root_subject}"])
        end

        it 'uses a generic message if error_string is nil' do
          ssl_context.stubs(:error_string).returns(nil)
          ssl_context.stubs(:error).returns(code)

          subject.call(false, ssl_context)
          expect(subject.verify_errors).to eq(["OpenSSL error #{code} for #{root_subject}"])
        end

        it 'uses 0 for nil error codes' do
          ssl_context.stubs(:error_string).returns("Something went wrong")
          ssl_context.stubs(:error).returns(nil)

          subject.call(false, ssl_context)
          expect(subject.verify_errors).to eq(["Something went wrong for #{root_subject}"])
        end

        context "when CRL is not yet valid" do
          before :each do
            ssl_context.stubs(:error_string).returns("CRL is not yet valid")
            ssl_context.stubs(:error).returns(OpenSSL::X509::V_ERR_CRL_NOT_YET_VALID)
          end

          it 'rejects nil CRL' do
            ssl_context.stubs(:current_crl).returns(nil)

            expect(subject.call(false, ssl_context)).to eq(false)
            expect(subject.verify_errors).to eq(["CRL is not yet valid"])
          end

          it 'includes the CRL issuer in the verify error message' do
            crl = OpenSSL::X509::CRL.new
            crl.issuer = OpenSSL::X509::Name.new([['CN','Puppet CA: puppetmaster.example.com']])
            crl.last_update = Time.now + 24 * 60 * 60
            ssl_context.stubs(:current_crl).returns(crl)

            subject.call(false, ssl_context)
            expect(subject.verify_errors).to eq(["CRL is not yet valid for /CN=Puppet CA: puppetmaster.example.com"])
          end

          it 'rejects CRLs whose last_update time is more than 5 minutes in the future' do
            crl = OpenSSL::X509::CRL.new
            crl.issuer = OpenSSL::X509::Name.new([['CN','Puppet CA: puppetmaster.example.com']])
            crl.last_update = Time.now + 24 * 60 * 60
            ssl_context.stubs(:current_crl).returns(crl)

            expect(subject.call(false, ssl_context)).to eq(false)
          end

          it 'accepts CRLs whose last_update time is 10 seconds in the future' do
            crl = OpenSSL::X509::CRL.new
            crl.issuer = OpenSSL::X509::Name.new([['CN','Puppet CA: puppetmaster.example.com']])
            crl.last_update = Time.now + 10
            ssl_context.stubs(:current_crl).returns(crl)

            expect(subject.call(false, ssl_context)).to eq(true)
          end
        end
      end
    end

    context 'When pre-verification is OK' do
      context 'and the ssl_context is in an error state' do
        before :each do
          ssl_context.stubs(:error_string).returns("Something went wrong")
        end

        it 'does not make the error available via #verify_errors' do
          subject.call(true, ssl_context)
          expect(subject.verify_errors).to eq([])
        end
      end

      context 'and the chain is valid' do
        it 'is true for each CA certificate in the chain' do
          (cert_chain.length - 1).times do
            expect(subject.call(true, ssl_context)).to be_truthy
          end
        end

        it 'is true for the SSL certificate ending the chain' do
          (cert_chain.length - 1).times do
            subject.call(true, ssl_context)
          end
          expect(subject.call(true, ssl_context)).to be_truthy
        end
      end

      context 'and the chain is invalid' do
        before :each do
          subject.stubs(:read_file).returns(@pki[:unrevoked_leaf_node_cert])
        end

        it 'is true for each CA certificate in the chain' do
          (cert_chain.length - 1).times do
            expect(subject.call(true, ssl_context)).to be_truthy
          end
        end

        it 'is false for the SSL certificate ending the chain' do
          (cert_chain.length - 1).times do
            subject.call(true, ssl_context)
          end
          expect(subject.call(true, ssl_context)).to be_falsey
        end
      end

      context 'an error is raised inside of #call' do
        before :each do
          ssl_context.expects(:current_cert).raises(StandardError, "BOOM!")
        end

        it 'is false' do
          expect(subject.call(true, ssl_context)).to be_falsey
        end

        it 'makes the error available through #verify_errors' do
          subject.call(true, ssl_context)
          expect(subject.verify_errors).to eq(["BOOM!"])
        end
      end
    end
  end

  describe '#setup_connection' do
    it 'updates the connection for verification' do
      subject.stubs(:ssl_certificates_are_present?).returns(true)
      connection = mock('Net::HTTP')

      connection.expects(:cert_store=).with(ssl_host.ssl_store)
      connection.expects(:ca_file=).with(ca_path)
      connection.expects(:cert=).with(ssl_host.certificate.content)
      connection.expects(:key=).with(ssl_host.key.content)
      connection.expects(:verify_callback=).with(subject)
      connection.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

      subject.setup_connection(connection, ssl_host)
    end

    context 'when no file path is found' do

      it 'does not perform verification if certificate files are missing' do
        subject.stubs(:ssl_certificates_are_present?).returns(false)
        connection = mock('Net::HTTP')

        connection.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)

        subject.setup_connection(connection, ssl_host)
      end
    end
  end

  describe '#valid_peer?' do
    before :each do
      subject.instance_variable_set(:@peer_certs, cert_chain_in_callback_order)
    end

    context 'when the peer presents a valid chain' do
      before :each do
        subject.stubs(:has_authz_peer_cert).returns(true)
      end

      it 'is true' do
        expect(subject.valid_peer?).to be_truthy
      end
    end

    context 'when the peer presents an invalid chain' do
      before :each do
        subject.stubs(:has_authz_peer_cert).returns(false)
      end

      it 'is false' do
        expect(subject.valid_peer?).to be_falsey
      end

      it 'makes a helpful error message available via #verify_errors' do
        subject.valid_peer?
        expect(subject.verify_errors).to eq([expected_authz_error_msg])
      end
    end
  end

  describe '#has_authz_peer_cert' do
    context 'when the Root CA is listed as authorized' do
      it 'returns true when the SSL cert is issued by the Master CA' do
        expect(subject.has_authz_peer_cert(cert_chain, [@pki[:root_cert]])).to be_truthy
      end

      it 'returns true when the SSL cert is issued by the alternate CA' do
        expect(subject.has_authz_peer_cert(cert_chain_alternate, [@pki[:root_cert]])).to be_truthy
      end
    end

    context 'when one intermediate CA is listed as authorized' do
      it 'returns true when the SSL cert is issued by the same intermediate CA' do
        expect(subject.has_authz_peer_cert(cert_chain, [@pki[:int_cert]])).to be_truthy
      end

      it 'returns false when the SSL cert is issued by a different intermediate CA' do
        expect(subject.has_authz_peer_cert(cert_chain_alternate, [@pki[:int_cert]])).to be_falsey
      end
    end
  end

  def cert_chain
    [@pki[:int_node_cert], @pki[:int_cert], @pki[:root_cert]]
  end

  def cert_chain_alternate
    [@pki[:unrevoked_leaf_node_cert], @pki[:leaf_cert], @pki[:revoked_int_cert], @pki[:root_cert]]
  end

  def cert_chain_in_callback_order
    cert_chain.reverse
  end

  let :authz_error_prefix do
    "The server presented a SSL certificate chain which does not include a CA listed in the ssl_client_ca_auth file.  "
  end

  let :expected_authz_error_msg do
    authz_ca_certs = subject.decode_cert_bundle(subject.read_file)
    msg = authz_error_prefix
    msg << "Authorized Issuers: #{authz_ca_certs.collect {|c| c.subject}.join(', ')}  "
    msg << "Peer Chain: #{cert_chain.collect {|c| c.subject}.join(' => ')}"
    msg
  end
end
