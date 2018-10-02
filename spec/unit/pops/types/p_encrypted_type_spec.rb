require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'
require 'puppet/test_ca'


module Puppet::Pops
module Types
describe 'The Encrypted Type' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  let(:test_ca) { Puppet::TestCa.new }
  let(:issuer) { test_ca.ca_cert }

  let(:host) { Puppet::SSL::Host.new("example.com") }
  let(:other_host) { Puppet::SSL::Host.new("example2.com") }
  let(:third_host) { Puppet::SSL::Host.new("example3.com") }
  let(:bad_host) { Puppet::SSL::Host.new("bad_example.com") }

  let(:host_key)       { OpenSSL::PKey::RSA.new(1024) }
  let(:other_host_key) { OpenSSL::PKey::RSA.new(1024) }
  let(:third_host_key) { OpenSSL::PKey::RSA.new(1024) }

  let(:host_cert)       { generate(test_ca(), 'example.com', host_key) }
  let(:other_host_cert) { generate(test_ca(),'example2.com', other_host_key) }
  let(:third_host_cert) { generate(test_ca(), 'example3.com', third_host_key) }

  def generate(testca, name, host_key)
    # create_csr is a private method in TestCa
    csr = testca.send(:create_csr, name, host_key)
    testca.sign(csr, {})
  end

  before(:each) do
    host.expects(:certificate).at_least(0).returns(host_cert)
    other_host.expects(:certificate).at_least(0).returns(other_host_cert)
    third_host.expects(:certificate).at_least(0).returns(third_host_cert)

    # At runtime the Host.key methods returns Puppet::SSL::Key, and the content is the RSA private key
    wrapped_key_host = mock()
    wrapped_key_host.stubs(:content).returns(host_key)

    wrapped_key_other_host = mock()
    wrapped_key_other_host.stubs(:content).returns(other_host_key)

    wrapped_key_third_host = mock()
    wrapped_key_third_host.stubs(:content).returns(third_host_key)

    host.expects(:key).at_least(0).returns(wrapped_key_host)
    other_host.expects(:key).at_least(0).returns(wrapped_key_other_host)
    third_host.expects(:key).at_least(0).returns(wrapped_key_third_host)
    bad_host.expects(:key).at_least(0).returns(nil)

    Puppet::SSL::Host.expects(:new).with('example.com').at_least(0).returns(host)
    Puppet::SSL::Host.expects(:new).with('example2.com').at_least(0).returns(other_host)
    Puppet::SSL::Host.expects(:new).with('example3.com').at_least(0).returns(third_host)
    Puppet::SSL::Host.expects(:new).with('bad_example.com').at_least(0).returns(bad_host)

    Puppet.push_context({:rich_data => true}, "set rich_data to true for tests")

    dir = tmpdir("host_integration_testing")

    Puppet.settings[:confdir] = dir
    Puppet.settings[:vardir] = dir
  end

  after(:each) {
    Puppet.pop_context()
  }

  shared_examples_for :encrypted_values do
    before(:each) {
      Puppet::SSL::Host.stubs(:localhost).returns(host)
    }
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
        Puppet[:accepted_ciphers] = []
        # Note AES-192-CBC used in test is not among default accepted ciphers
        code = <<-CODE
          $x = Encrypted("secret", cipher => 'AES-192-CBC')
          notice($x.decrypt('example.com').unwrap)
        CODE
        expect(eval_and_collect_notices(code, Puppet::Node.new('example.com'))).to eql(['secret'])
      end

      it 'Encryption selects preferred cipher if given an array of ciphers' do
        Puppet[:rich_data] = true

        code = <<-CODE
          $x = Encrypted("secret", cipher => ['AES-192-CBC', 'AES-128-CBC', 'AES-256-CBC'])
        notify {'example': message => $x}
        CODE
        catalog = compile_to_catalog(code, Puppet::Node.new('example.com'))
        json_catalog = JSON::pretty_generate(catalog.to_resource)
        catalog_hash = JSON::parse(json_catalog)
        example_hash = catalog_hash['resources'].select {|x| x['title']=='example'}[0]
        example_message = example_hash['parameters']['message']
        # format is static so can be checked
        expect(example_message['format']).to eql('json,AES-256-CBC')
      end

      it 'Encryption uses first defined cipher in accepted_ciphers' do
        Puppet[:rich_data] = true
        Puppet[:accepted_ciphers] = ['AES-192-CBC']
        code = <<-CODE
          $x = Encrypted("secret")
        notify {'example': message => $x}
        CODE
        catalog = compile_to_catalog(code, Puppet::Node.new('example.com'))
        json_catalog = JSON::pretty_generate(catalog.to_resource)
        catalog_hash = JSON::parse(json_catalog)
        example_hash = catalog_hash['resources'].select {|x| x['title']=='example'}[0]
        example_message = example_hash['parameters']['message']
        # format is static so can be checked
        expect(example_message['format']).to eql('json,AES-192-CBC')
      end

      it 'Encryption uses AES-256-CBC if accepted_ciphers is empty' do
        Puppet[:rich_data] = true
        Puppet[:accepted_ciphers] = []
        code = <<-CODE
          $x = Encrypted("secret")
        notify {'example': message => $x}
        CODE
        catalog = compile_to_catalog(code, Puppet::Node.new('example.com'))
        json_catalog = JSON::pretty_generate(catalog.to_resource)
        catalog_hash = JSON::parse(json_catalog)
        example_hash = catalog_hash['resources'].select {|x| x['title']=='example'}[0]
        example_message = example_hash['parameters']['message']
        # format is static so can be checked
        expect(example_message['format']).to eql('json,AES-256-CBC')
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

      it 'Encryption raises an error when given & accepted produces empty set - none match' do
        Puppet[:accepted_ciphers] = ['AES-192-CBC']
        code = <<-CODE
          Encrypted("secret", cipher => ['AES-256-CBC', 'AES-128-CBC'])
        CODE
        expect {
          compile_to_catalog(code, Puppet::Node.new('example.com'))
        }.to raise_error(/None of the cipher names.*Supported.*AES-192-CBC/)
      end
    end
  end

  describe 'when agent requests a catalog creating encrypted values' do

    # This configures the runtime with TrustedInformation the same way as
    # a request for a catalog does. (requesting host is not the same as compiling host).
    #
    before(:each) {
      # found_cert = Puppet::SSL::Certificate.indirection.find(@host.name)
      found_cert = host_cert

      fake_authentication = true
      trusted_information = Puppet::Context::TrustedInformation.remote(fake_authentication, host.name, found_cert)
      Puppet.push_context({:trusted_information => trusted_information}, "Fake trusted information for p_encrypted_type_spec.rb")
      Puppet::SSL::Host.stubs(:localhost).returns(other_host)
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
          expect(the_message.decrypt(scope, host).unwrap).to eql('There, and Back Again')
        end
      end
    end

  end

  describe 'when using apply and a catalog is creating encrypted values' do

    # This configures the runtime with TrustedInformation the same way as
    # a puppet apply does (requesting host is the same as compiling host).
    #
    before(:each) {
#      found_cert = Puppet::SSL::Certificate.indirection.find(@host.name)
      found_cert = host_cert

      fake_authentication = true
      trusted_information = Puppet::Context::TrustedInformation.remote(fake_authentication, host.name, found_cert)
      Puppet.push_context({:trusted_information => trusted_information}, "Fake trusted information for p_encrypted_type_spec.rb")
      Puppet::SSL::Host.stubs(:localhost).returns(host)
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
