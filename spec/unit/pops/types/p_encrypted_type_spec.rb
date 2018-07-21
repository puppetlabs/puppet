require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'The Encrypted Type' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files


  before(:each) do
    # Configure a CA and create host certificates used when testing

    # Get a safe temporary file for CA stuff
    dir = tmpdir("host_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir

    Puppet::SSL::Host.ca_location = :local

    @ca = Puppet::SSL::CertificateAuthority.new

    # The catalog requesting host / and localhost in apply
    @host = Puppet::SSL::Host.new("example.com")
    @host.generate_key
    @host.generate_certificate_request

    # The compiling (local) host in tests for agent/master
    @other_host = Puppet::SSL::Host.new("example2.com")
    @other_host.generate_key
    @other_host.generate_certificate_request

    # host that is neither requesting or compiling
    @third_host = Puppet::SSL::Host.new("example3.com")
    @third_host.generate_key
    @third_host.generate_certificate_request

    @ca.sign(@host.name)
    @ca.sign(@other_host.name)
    @ca.sign(@third_host.name)
  end

  after(:each) {
    Puppet::SSL::Host.ca_location = :none
  }

  shared_examples_for :encrypted_values do
    context 'supports operations at the type level, such that' do
      it 'Type[Encrypted] can be obtained from the type factory' do
        t = TypeFactory.encrypted()
        expect(t).to be_a(PEncryptedType)
        expect(t).to eql(PEncryptedType::DEFAULT)
      end

      it 'Type[Encrypted] can be obtained via its name in Puppet' do
        code = <<-CODE
          $x = Encrypted
          notice(($x =~ Type[Encrypted]).convert_to(String))
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['true'])
      end

      it 'Type[Encrypted] is an Any' do
        code = <<-CODE
          notice((Encrypted < Any).convert_to(String))
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['true'])
      end

      it 'Type[Encrypted] is not an Object' do
        code = <<-CODE
          notice((Encrypted < Object).convert_to(String))
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['false'])
      end

      it 'Type[Encrypted] is a RichData' do
        code = <<-CODE
          notice((Encrypted < RichData).convert_to(String))
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['true'])
      end
    end

    context 'supports operations such that' do
      it 'Encrypted.new returns an Encrypted value' do
        code = <<-CODE
          $x = Encrypted("secret")
          notice(($x =~ Encrypted).convert_to(String))
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['true'])
      end

      it 'an Encrypted value is only equal to itself' do
        code = <<-CODE
          $x = Encrypted("secret")
          $y = Encrypted("secret")
          notice(($x == $x and $x != $y and $y == $y).convert_to(String))
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['true'])
      end

      it 'Decryption for a given host can be performed when private key is known for host' do
        code = <<-CODE
          $x = Encrypted("secret")
          notice($x.decrypt('example.com').unwrap)
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
      end

      it 'Encryption can be performed when public key is known for a host' do
        code = <<-CODE
          $x = Encrypted("secret", node_name=> 'example3.com')
          notice($x.decrypt('example3.com').unwrap)
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
      end

      it 'Encryption can be performed with a given cipher' do
        code = <<-CODE
          $x = Encrypted("secret", cipher => 'AES-256-CBC', node_name => 'example3.com')
          notice($x.decrypt('example3.com').unwrap)
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
      end

      it 'Encryption raises an error for unknown cipher and displays list of the available' do
        code = <<-CODE
          $x = Encrypted("secret", cipher => 'ROT13-HA-HA')
          notice($x.decrypt('example3.com').unwrap)
        CODE
        expect {
          compile_to_catalog(code, Puppet::Node.new('example.com'))
        }.to raise_error(/Unsupported cipher algorithm.*Supported.*AES-256-CBC/) # AES-256-CBC is available
      end

      it 'Encryption raises an error for unacceptable cipher and displays list of the acceptable' do
        code = <<-CODE
          $x = Encrypted("secret", cipher => 'AES-192-CBC')
          notice($x.decrypt('example3.com').unwrap)
        CODE
        expect {
          compile_to_catalog(code, Puppet::Node.new('example.com'))
        }.to raise_error(/Unsupported cipher algorithm.*Supported.*AES-256-CBC/) # AES-256-CBC is acceptable by default
      end

      it 'Encryption uses all available ciphers if --accepted_ciphers is set to empty string' do
        Puppet[:accepted_ciphers] = ''
        # Note AES-192-CBC used in test is not among default accepted ciphers
        code = <<-CODE
          $x = Encrypted("secret", cipher => 'AES-192-CBC')
          notice($x.decrypt('example.com').unwrap)
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
      end

      it 'Decryption for a given host fails if there is no private key' do
        code = <<-CODE
          Encrypted("secret").decrypt('bad_example.com')
        CODE
        expect {
          compile_to_catalog(code, Puppet::Node.new('example.com'))
        }.to raise_error {|error|
          expect(error).to be_a(Puppet::PreformattedError)
          expect(error.cause).to be_a(Puppet::DecryptionError)
        }
      end
    end
  end

  describe 'when agent requests a catalog creating encrypted values' do

    # This configures the runtime with TrustedInformation the same way as
    # a request for a catalog does. (requesting host is not the same as compiling host).
    #
    before(:each) {
      found_cert = Puppet::SSL::Certificate.indirection.find(@host.name)

      fake_authentication = true
      trusted_information = Puppet::Context::TrustedInformation.remote(fake_authentication, @host.name, found_cert)
      Puppet.push_context({:trusted_information => trusted_information}, "Fake trusted information for p_encrypted_type_spec.rb")
      Puppet::SSL::Host.stubs(:localhost).returns(@other_host)
    }

    after(:each) {
      Puppet.pop_context
    }

    it_behaves_like :encrypted_values

    it 'a decryption fails since it will use localhost as recipient and encryption is for catalog requesting node' do
      code = <<-CODE
        Encrypted("secret").decrypt
      CODE
      expect {
        compile_to_catalog(code, Puppet::Node.new('example.com'))
      }.to raise_error { |error|
        expect(error).to be_a(Puppet::PreformattedError)
        expect(error.cause).to be_a(Puppet::DecryptionError)
      }
    end

    context 'when serializing a catalog with an Encrypted' do
      it 'an Encrypted in a catalog is serialized as rich data' do
        Puppet[:rich_data] = true

        code = <<-CODE
          notify { 'example':
            message => Encrypted("secret")
          }
        CODE
        catalog = compile_to_catalog(code, Puppet::Node.new('example.com'))
        json_catalog = JSON::pretty_generate(catalog.to_resource)
        catalog_hash = JSON::parse(json_catalog)
        example_hash = catalog_hash['resources'].select {|x| x['title']=='example'}[0]
        example_message = example_hash['parameters']['message']
        # format is static so can be checked
        expect(example_message['format']).to eql('json,AES-256-CBC')

        # values for the other keys are random - cannot check values
        # check that keys are present (is a good enough catalog serialization test)
        # as this just tests that a serialization to rich json took place, it is 
        # not testing the actual format.
        keys = example_message.keys
        expect(keys).to include('format','encrypted_key', 'crypt', 'encrypted_fingerprint')
      end
    end

    context 'when deserializing a catalog with an Encrypted' do
      let(:env) { Puppet::Node::Environment.create(:testing, []) }
      let(:loader) { Loaders.find_loader(nil) }

      before(:each) do
        Puppet.push_context(:loaders => Loaders.new(env))
      end

      after(:each) do
        Puppet.pop_context()
      end

      it 'an Encrypted in a rich data catalog is deserialized to an Encrypted' do
        Puppet[:rich_data] = true

        code = <<-CODE
          notify { 'example':
            message => Encrypted('There, and Back Again')
          }
        CODE

        # Use eval and collect notices as it supports getting the catalog before it
        # goes out of scope (test ignores collected notices).
        eval_and_collect_notices(code, Puppet::Node.new('example.com')) do |scope, catalog|
          # serialize it
          json_catalog = JSON::pretty_generate(catalog.to_resource)

          # deserialize via the Catalog
          deserialized_catalog = Puppet::Resource::Catalog.convert_from('json', json_catalog)
          notify_resource = deserialized_catalog.resource('Notify[example]')
          the_message = notify_resource.parameters[:message]
          expect(the_message).to be_a(Puppet::Pops::Types::PEncryptedType::Encrypted)
          expect(the_message.format).to eql('json,AES-256-CBC')
          expect(the_message.encrypted_fingerprint).to be_a(Puppet::Pops::Types::PBinaryType::Binary)
          expect(the_message.encrypted_key).to be_a(Puppet::Pops::Types::PBinaryType::Binary)
          expect(the_message.crypt).to be_a(Puppet::Pops::Types::PBinaryType::Binary)

          # localhost is @other_host, so give catalog requesting @host here
          expect(the_message.decrypt(scope, @host).unwrap).to eql('There, and Back Again')
        end
      end
    end

  end

  describe 'when using apply and a catalog is creating encrypted values' do

    # This configures the runtime with TrustedInformation the same way as
    # a puppet apply does (requesting host is the same as compiling host).
    #
    before(:each) {
      found_cert = Puppet::SSL::Certificate.indirection.find(@host.name)

      fake_authentication = true
      trusted_information = Puppet::Context::TrustedInformation.remote(fake_authentication, @host.name, found_cert)
      Puppet.push_context({:trusted_information => trusted_information}, "Fake trusted information for p_encrypted_type_spec.rb")
      Puppet::SSL::Host.stubs(:localhost).returns(@host)
    }

    after(:each) {
      Puppet.pop_context
    }

    it_behaves_like :encrypted_values

    it 'an Encrypted can be decrypted with the decrypt() function without specifying node_name' do
      code = <<-CODE
        $x = Encrypted("secret")
        notice($x.decrypt.unwrap)
      CODE
      expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
    end

    it 'a decrypted result is an instance of Sensitive, and is not wrapped in another Sensitive if original was already' do
      code = <<-CODE
        $x = Encrypted(Sensitive("secret"))
        notice($x.decrypt.unwrap)
      CODE
      expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
    end

    it 'the result of decrypt() is an instance of Sensitive' do
      code = <<-CODE
        $x = Encrypted("secret").decrypt
        notice("sensitive it ${ if $x =~  Sensitive { 'is' }}")
      CODE
      expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['sensitive it is'])
    end
  end

end
end
end
