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

  describe "when :strict is off" do
    before :each do
      Puppet.settings[:strict] = :off
    end

    after :all do
      Puppet.settings[:strict] = Puppet.settings.setting(:strict).default
    end

    it "should not warn if compared against another symbol" do
      Puppet.expects(:warn_once).never
      expect(:foo <=> :bar).to equal(1)
    end

    it "should not warn if compared against a non-symbol value" do
      Puppet.expects(:warn_once).never
      expect(:foo <=> "foo").to equal(0)
    end
  end

  describe "when :strict is warning" do
    before :each do
      Puppet.settings[:strict] = :warning
    end

    after :all do
      Puppet.settings[:strict] = Puppet.settings.setting(:strict).default
    end

    it "should not warn if compared against another symbol" do
      Puppet.expects(:warn_once).never
      expect(:foo <=> :bar).to equal(1)
    end

    it "should warn if compared against a non-symbol value" do
      Puppet.expects(:warn_once).once
      expect(:foo <=> "foo").to equal(0)
    end
  end

  describe "when :strict is error" do
    before :each do
      Puppet.settings[:strict] = :error
    end

    after :all do
      Puppet.settings[:strict] = Puppet.settings.setting(:strict).default
    end

    it "should not raise if compared against another symbol" do
      Puppet.expects(:warn_once).never
      expect(:foo <=> :bar).to equal(1)
    end

    it "should raise if compared against a non-symbol value" do
      Puppet.expects(:warn_once).never
      expect { :foo <=> "foo" }.to raise_error(ArgumentError, "Comparing Symbols to non-Symbol values is no longer allowed")
    end
  end
end

describe IO do
  include PuppetSpec::Files

  let(:file) { tmpfile('io-binary') }
  let(:content) { "\x01\x02\x03\x04" }

  describe "::binwrite" do
    it "should write in binary mode" do
      expect(IO.binwrite(file, content)).to eq(content.length)
      File.open(file, 'rb') {|f| expect(f.read).to eq(content) }
    end

    (0..10).each do |offset|
      it "should write correctly using an offset of #{offset}" do
        expect(IO.binwrite(file, content, offset)).to eq(content.length)
        File.open(file, 'rb') {|f| expect(f.read).to eq(("\x00" * offset) + content) }
      end
    end

    context "truncation" do
      let :input do "welcome to paradise, population ... YOU!" end
      before :each do IO.binwrite(file, input) end

      it "should truncate if no offset is given" do
        expect(IO.binwrite(file, "boo")).to eq(3)
        expect(File.read(file)).to eq("boo")
      end

      (0..10).each do |offset|
        it "should not truncate if an offset of #{offset} is given" do
          expect = input.dup
          expect[offset, 3] = "BAM"

          expect(IO.binwrite(file, "BAM", offset)).to eq(3)
          expect(File.read(file)).to eq(expect)
        end
      end

      it "should pad with NULL bytes if writing past EOF without truncate" do
        expect = input + ("\x00" * 4) + "BAM"
        expect(IO.binwrite(file, "BAM", input.length + 4)).to eq(3)
        expect(File.read(file)).to eq(expect)
      end
    end

    it "should raise an error if the directory containing the file doesn't exist" do
      expect { IO.binwrite('/path/does/not/exist', 'foo') }.to raise_error(Errno::ENOENT)
    end
  end
end

describe Range do
  def do_test( range, other, expected )
    result = range.intersection(other)
    expect(result).to eq(expected)
  end

  it "should return expected ranges for iterable things" do
    iterable_tests = {
      1  .. 4   => nil,          # before
      11 .. 15  => nil,          # after
      1  .. 6   => 5  ..  6,     # overlap_begin
      9  .. 15  => 9  ..  10,    # overlap_end
      1  .. 5   => 5  ..  5,     # overlap_begin_edge
      10 .. 15  => 10 ..  10,    # overlap_end_edge
      5  .. 10  => 5  ..  10,    # overlap_all
      6  .. 9   => 6  ..  9,     # overlap_inner

      1 ... 5   => nil,          # before             (exclusive range)
      1 ... 7   => 5  ... 7,     # overlap_begin      (exclusive range)
      1 ... 6   => 5  ... 6,     # overlap_begin_edge (exclusive range)
      5 ... 11  => 5  ..  10,    # overlap_all        (exclusive range)
      6 ... 10  => 6  ... 10,    # overlap_inner      (exclusive range)
    }

    iterable_tests.each do |other, expected|
      do_test( 5..10, other, expected )
      do_test( other, 5..10, expected )
    end
  end

  it "should return expected ranges for noniterable things" do
    inclusive_base_case = {
      1.to_f  .. 4.to_f   => nil,                   # before
      11.to_f .. 15.to_f  => nil,                   # after
      1.to_f  .. 6.to_f   => 5.to_f  ..  6.to_f,    # overlap_begin
      9.to_f  .. 15.to_f  => 9.to_f  ..  10.to_f,   # overlap_end
      1.to_f  .. 5.to_f   => 5.to_f  ..  5.to_f,    # overlap_begin_edge
      10.to_f .. 15.to_f  => 10.to_f ..  10.to_f,   # overlap_end_edge
      5.to_f  .. 10.to_f  => 5.to_f  ..  10.to_f,   # overlap_all
      6.to_f  .. 9.to_f   => 6.to_f  ..  9.to_f,    # overlap_inner

      1.to_f ... 5.to_f   => nil,                   # before             (exclusive range)
      1.to_f ... 7.to_f   => 5.to_f  ... 7.to_f,    # overlap_begin      (exclusive range)
      1.to_f ... 6.to_f   => 5.to_f  ... 6.to_f,    # overlap_begin_edge (exclusive range)
      5.to_f ... 11.to_f  => 5.to_f  ..  10.to_f,   # overlap_all        (exclusive range)
      6.to_f ... 10.to_f  => 6.to_f  ... 10.to_f,   # overlap_inner      (exclusive range)
    }

    inclusive_base_case.each do |other, expected|
      do_test( 5.to_f..10.to_f, other, expected )
      do_test( other, 5.to_f..10.to_f, expected )
    end

    exclusive_base_case = {
      1.to_f  .. 4.to_f   => nil,                   # before
      11.to_f .. 15.to_f  => nil,                   # after
      1.to_f  .. 6.to_f   => 5.to_f  ..  6.to_f,    # overlap_begin
      9.to_f  .. 15.to_f  => 9.to_f  ... 10.to_f,   # overlap_end
      1.to_f  .. 5.to_f   => 5.to_f  ..  5.to_f,    # overlap_begin_edge
      10.to_f .. 15.to_f  => nil,                   # overlap_end_edge
      5.to_f  .. 10.to_f  => 5.to_f  ... 10.to_f,   # overlap_all
      6.to_f  .. 9.to_f   => 6.to_f  ..  9.to_f,    # overlap_inner

      1.to_f ... 5.to_f   => nil,                   # before             (exclusive range)
      1.to_f ... 7.to_f   => 5.to_f  ... 7.to_f,    # overlap_begin      (exclusive range)
      1.to_f ... 6.to_f   => 5.to_f  ... 6.to_f,    # overlap_begin_edge (exclusive range)
      5.to_f ... 11.to_f  => 5.to_f  ... 10.to_f,   # overlap_all        (exclusive range)
      6.to_f ... 10.to_f  => 6.to_f  ... 10.to_f,   # overlap_inner      (exclusive range)
    }

    exclusive_base_case.each do |other, expected|
      do_test( 5.to_f...10.to_f, other, expected )
      do_test( other, 5.to_f...10.to_f, expected )
    end
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
    expect(cipher_str.split(':')).to include('!SSLv2')
  end

  it 'does not exclude SSLv3 ciphers shared with TLSv1' do
    cipher_str = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers]
    expect(cipher_str.split(':')).not_to include('!SSLv3')
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
