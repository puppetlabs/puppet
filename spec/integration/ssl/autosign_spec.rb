require 'spec_helper'

describe "autosigning" do
  include PuppetSpec::Files

  let(:puppet_dir) { tmpdir("ca_autosigning") }
  let(:csr_attributes_content) do
    {
      'custom_attributes' => {
        '1.3.6.1.4.1.34380.2.0' => 'hostname.domain.com',
        '1.3.6.1.4.1.34380.2.1' => 'my passphrase',
        '1.3.6.1.4.1.34380.2.2' => # system IPs in hex
          [ 0xC0A80001, # 192.168.0.1
            0xC0A80101 ], # 192.168.1.1
      },
      'extension_requests' => {
        'pp_uuid' => 'abcdef',
        '1.3.6.1.4.1.34380.1.1.2' => '1234', # pp_instance_id
        '1.3.6.1.4.1.34380.1.2.1' => 'some-value', # private extension
      },
    }
  end

  let(:host) { Puppet::SSL::Host.new }

  before do
    Puppet.settings[:confdir] = puppet_dir
    Puppet.settings[:vardir] = puppet_dir

    # This is necessary so the terminus instances don't lie around.
    Puppet::SSL::Key.indirection.termini.clear
  end

  context "with extension requests from csr_attributes file" do
    let(:ca) { Puppet::SSL::CertificateAuthority.new }

    def write_csr_attributes
      File.open(Puppet.settings[:csr_attributes], 'w') do |file|
        file.puts YAML.dump(csr_attributes_content)
      end
    end

    context "and subjectAltName" do
      it "raises an error if you include subjectAltName in csr_attributes" do
        csr_attributes_content['extension_requests']['subjectAltName'] = 'foo'
        write_csr_attributes
        expect { host.generate_certificate_request }.to raise_error(Puppet::Error, /subjectAltName.*conflicts with internally used extension request/)
      end

      it "properly merges subjectAltName when in settings" do
        Puppet.settings[:dns_alt_names] = 'althostname.nowhere'
        write_csr_attributes
        host.generate_certificate_request
        csr = Puppet::SSL::CertificateRequest.indirection.find(host.name)
        expect(csr.subject_alt_names).to include('DNS:althostname.nowhere')
      end
    end

    context "without subjectAltName" do

      before do
        write_csr_attributes
        host.generate_certificate_request
      end

      it "pulls extension attributes from the csr_attributes file into the certificate" do
        csr = Puppet::SSL::CertificateRequest.indirection.find(host.name)
        expect(csr.request_extensions).to have(3).items
        expect(csr.request_extensions).to include('oid' => 'pp_uuid', 'value' => 'abcdef')
        expect(csr.request_extensions).to include('oid' => 'pp_instance_id', 'value' => '1234')
        expect(csr.request_extensions).to include('oid' => '1.3.6.1.4.1.34380.1.2.1', 'value' => 'some-value')
      end

      it "copies extension requests to certificate" do
        cert = ca.sign(host.name)
        expect(cert.custom_extensions).to include('oid' => 'pp_uuid', 'value' => 'abcdef')
        expect(cert.custom_extensions).to include('oid' => 'pp_instance_id', 'value' => '1234')
        expect(cert.custom_extensions).to include('oid' => '1.3.6.1.4.1.34380.1.2.1', 'value' => 'some-value')
      end

      it "does not copy custom attributes to certificate" do
        cert = ca.sign(host.name)
        cert.custom_extensions.each do |ext|
          expect(Puppet::SSL::Oids.subtree_of?('1.3.6.1.4.1.34380.2', ext['oid'])).to be_false
        end
      end
    end

  end
end
