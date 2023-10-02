require 'spec_helper'

require 'puppet/util/monkey_patches'

describe Dir do
  describe '.exists?' do
    it 'returns false if the directory does not exist' do
      expect(Dir.exists?('/madeupdirectory')).to be false
    end

    it 'returns true if the directory exists' do
      expect(Dir.exists?(__dir__)).to be true
    end

    if RUBY_VERSION >= '3.2' 
      it 'logs a warning message' do
        expect(Puppet).to receive(:warning).with('exists? is a deprecated name, use exist? instead')
        Dir.exists?(__dir__)
      end
    end
  end
end

describe File do
  describe '.exists?' do
    it 'returns false if the directory does not exist' do
      expect(File.exists?('spec/unit/util/made_up_file')).to be false
    end

    it 'returns true if the file exists' do
      expect(File.exists?(__FILE__)).to be true
    end

    if RUBY_VERSION >= '3.2'
      it 'logs a warning message' do
        expect(Puppet).to receive(:warning).with('exists? is a deprecated name, use exist? instead')
        File.exists?(__FILE__)
      end
    end
  end
end

describe Symbol do
  after :all do
    $unique_warnings.delete('symbol_comparison') if $unique_warnings
  end

  it 'should have an equal? that is not true for a string with same letters' do
    symbol = :undef
    expect(symbol).to_not equal('undef')
  end

  it "should have an eql? that is not true for a string with same letters" do
    symbol = :undef
    expect(symbol).to_not eql('undef')
  end

  it "should have an == that is not true for a string with same letters" do
    symbol = :undef
    expect(symbol == 'undef').to_not be(true)
  end

  it "should return self from #intern" do
    symbol = :foo
    expect(symbol).to equal symbol.intern
  end
end

describe OpenSSL::SSL::SSLContext do
  it 'disables SSLv3 via the SSLContext#options bitmask' do
    expect(subject.options & OpenSSL::SSL::OP_NO_SSLv3).to eq(OpenSSL::SSL::OP_NO_SSLv3)
  end

  it 'does not exclude SSLv3 ciphers shared with TLSv1' do
    cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
    if cipher_str
      expect(cipher_str.split(':')).not_to include('!SSLv3')
    end
  end

  it 'sets parameters on initialization' do
    expect_any_instance_of(described_class).to receive(:set_params)
    subject
  end
end


describe OpenSSL::X509::Store, :if => Puppet::Util::Platform.windows? do
  let(:store)    { described_class.new }
  let(:cert)     { OpenSSL::X509::Certificate.new(File.read(my_fixture('x509.pem'))) }
  let(:samecert) { cert.dup() }

  def with_root_certs(certs)
    expect(Puppet::Util::Windows::RootCerts).to receive(:instance).and_return(certs)
  end

  it "adds a root cert to the store" do
    with_root_certs([cert])

    store.set_default_paths
  end

  it "doesn't warn when calling set_default_paths multiple times" do
    with_root_certs([cert])
    expect(store).not_to receive(:warn)

    store.set_default_paths
    store.set_default_paths
  end

  it "ignores duplicate root certs" do
    # prove that even though certs have identical contents, their hashes differ
    expect(cert.hash).to_not eq(samecert.hash)
    with_root_certs([cert, samecert])

    expect(store).to receive(:add_cert).with(cert).once
    expect(store).not_to receive(:add_cert).with(samecert)

    store.set_default_paths
  end

  # openssl 1.1.1 ignores duplicate certs
  # https://github.com/openssl/openssl/commit/c0452248ea1a59a41023a4765ef7d9825e80a62b
  if OpenSSL::OPENSSL_VERSION_NUMBER < 0x10101000
    it "warns when adding a certificate that already exists" do
      with_root_certs([cert])
      store.add_cert(cert)

      expect(store).to receive(:warn).with('Failed to add CN=Microsoft Root Certificate Authority,DC=microsoft,DC=com')

      store.set_default_paths
    end
  else
    it "doesn't warn when adding a duplicate cert" do
      with_root_certs([cert])
      store.add_cert(cert)

      expect(store).not_to receive(:warn)

      store.set_default_paths
    end
  end

  it "raises when adding an invalid certificate" do
    with_root_certs(['notacert'])

    expect {
      store.set_default_paths
    }.to raise_error(TypeError)
  end
end

describe SecureRandom do
  it 'generates a properly formatted uuid' do
    expect(SecureRandom.uuid).to match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i)
  end
end
