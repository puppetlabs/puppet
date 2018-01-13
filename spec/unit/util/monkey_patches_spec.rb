#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/monkey_patches'


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
    pending "JRuby is incompatible with MRI - Cannot test this on JRuby" if RUBY_PLATFORM == 'java'
    symbol = :undef
    expect(symbol == 'undef').to_not be(true)
  end

  it "should return self from #intern" do
    symbol = :foo
    expect(symbol).to equal symbol.intern
  end
end

describe OpenSSL::SSL::SSLContext do
  it 'disables SSLv2 via the SSLContext#options bitmask' do
    expect(subject.options & OpenSSL::SSL::OP_NO_SSLv2).to eq(OpenSSL::SSL::OP_NO_SSLv2)
  end

  it 'disables SSLv3 via the SSLContext#options bitmask' do
    expect(subject.options & OpenSSL::SSL::OP_NO_SSLv3).to eq(OpenSSL::SSL::OP_NO_SSLv3)
  end

  it 'explicitly disable SSLv2 ciphers using the ! prefix so they cannot be re-added' do
    cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
    if cipher_str
      expect(cipher_str.split(':')).to include('!SSLv2')
    end
  end

  it 'does not exclude SSLv3 ciphers shared with TLSv1' do
    cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
    if cipher_str
      expect(cipher_str.split(':')).not_to include('!SSLv3')
    end
  end

  it 'sets parameters on initialization' do
    described_class.any_instance.expects(:set_params)
    subject
  end

  it 'has no ciphers with version SSLv2 enabled' do
    ciphers = subject.ciphers.select do |name, version, bits, alg_bits|
      /SSLv2/.match(version)
    end
    expect(ciphers).to be_empty
  end
end


describe OpenSSL::X509::Store, :if => Puppet::Util::Platform.windows? do
  let(:store)    { described_class.new }
  let(:cert)     { OpenSSL::X509::Certificate.new(File.read(my_fixture('x509.pem'))) }
  let(:samecert) { cert.dup() }

  def with_root_certs(certs)
    Puppet::Util::Windows::RootCerts.expects(:instance).returns(certs)
  end

  it "adds a root cert to the store" do
    with_root_certs([cert])

    store.set_default_paths
  end

  it "doesn't warn when calling set_default_paths multiple times" do
    with_root_certs([cert])
    store.expects(:warn).never

    store.set_default_paths
    store.set_default_paths
  end

  it "ignores duplicate root certs" do
    # prove that even though certs have identical contents, their hashes differ
    expect(cert.hash).to_not eq(samecert.hash)
    with_root_certs([cert, samecert])

    store.expects(:add_cert).with(cert).once
    store.expects(:add_cert).with(samecert).never

    store.set_default_paths
  end

  it "warns when adding a certificate that already exists" do
    with_root_certs([cert])
    store.add_cert(cert)

    store.expects(:warn).with('Failed to add /DC=com/DC=microsoft/CN=Microsoft Root Certificate Authority')

    store.set_default_paths
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

describe 'Enumerable' do
  it 'expects uniq to work on an Enumerable' do
    expect(['c', 'c', 'C'].reverse_each.uniq).to eql(['C', 'c'])
  end
end
