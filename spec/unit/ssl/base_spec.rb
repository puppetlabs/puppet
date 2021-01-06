require 'spec_helper'

require 'puppet/ssl/certificate'

class TestCertificate < Puppet::SSL::Base
    wraps(Puppet::SSL::Certificate)
end

describe Puppet::SSL::Certificate do
  before :each do
    @base = TestCertificate.new("name")
    @class = TestCertificate
  end

  describe "when creating new instances" do
    it "should fail if given an object that is not an instance of the wrapped class" do
      obj = double('obj', :is_a? => false)
      expect { @class.from_instance(obj) }.to raise_error(ArgumentError)
    end

    it "should fail if a name is not supplied and can't be determined from the object" do
      obj = double('obj', :is_a? => true)
      expect { @class.from_instance(obj) }.to raise_error(ArgumentError)
    end

    it "should determine the name from the object if it has a subject" do
      obj = double('obj', :is_a? => true, :subject => '/CN=foo')

      inst = double('base')
      expect(inst).to receive(:content=).with(obj)

      expect(@class).to receive(:new).with('foo').and_return(inst)
      expect(@class).to receive(:name_from_subject).with('/CN=foo').and_return('foo')

      expect(@class.from_instance(obj)).to eq(inst)
    end
  end

  describe "when determining a name from a certificate subject" do
    it "should extract only the CN and not any other components" do
      name = OpenSSL::X509::Name.parse('/CN=host.domain.com/L=Portland/ST=Oregon')
      expect(@class.name_from_subject(name)).to eq('host.domain.com')
    end
  end

  describe "when initializing wrapped class from a file with #read" do
    it "should open the file with ASCII encoding" do
      path = '/foo/bar/cert'
      expect(Puppet::FileSystem).to receive(:read).with(path, :encoding => Encoding::ASCII).and_return("bar")
      @base.read(path)
    end
  end

  describe "#digest_algorithm" do
    let(:content) { double('content') }
    let(:base) {
      b = Puppet::SSL::Base.new('base')
      b.content = content
      b
    }

    # Some known signature algorithms taken from RFC 3279, 5758, and browsing
    # objs_dat.h in openssl
    {
      'md5WithRSAEncryption' => 'md5',
      'sha1WithRSAEncryption' => 'sha1',
      'md4WithRSAEncryption' => 'md4',
      'sha256WithRSAEncryption' => 'sha256',
      'ripemd160WithRSA' => 'ripemd160',
      'ecdsa-with-SHA1' => 'sha1',
      'ecdsa-with-SHA224' => 'sha224',
      'ecdsa-with-SHA256' => 'sha256',
      'ecdsa-with-SHA384' => 'sha384',
      'ecdsa-with-SHA512' => 'sha512',
      'dsa_with_SHA224' => 'sha224',
      'dsaWithSHA1' => 'sha1',
    }.each do |signature, digest|
      it "returns '#{digest}' for signature algorithm '#{signature}'" do
        allow(content).to receive(:signature_algorithm).and_return(signature)
        expect(base.digest_algorithm).to eq(digest)
      end
    end

    it "raises an error on an unknown signature algorithm" do
      allow(content).to receive(:signature_algorithm).and_return("nonsense")
      expect {
        base.digest_algorithm
      }.to raise_error(Puppet::Error, "Unknown signature algorithm 'nonsense'")
    end
  end

  describe "when getting a CN from a subject" do
    def parse(dn)
      OpenSSL::X509::Name.parse(dn)
    end

    def cn_from(subject)
      @class.name_from_subject(subject)
    end

    it "should correctly parse a subject containing only a CN" do
      subj = parse('/CN=foo')
      expect(cn_from(subj)).to eq('foo')
    end

    it "should correctly parse a subject containing other components" do
      subj = parse('/CN=Root CA/OU=Server Operations/O=Example Org')
      expect(cn_from(subj)).to eq('Root CA')
    end

    it "should correctly parse a subject containing other components with CN not first" do
      subj = parse('/emailAddress=foo@bar.com/CN=foo.bar.com/O=Example Org')
      expect(cn_from(subj)).to eq('foo.bar.com')
    end

    it "should return nil for a subject with no CN" do
      subj = parse('/OU=Server Operations/O=Example Org')
      expect(cn_from(subj)).to eq(nil)
    end

    it "should return nil for a bare string" do
      expect(cn_from("/CN=foo")).to eq(nil)
    end
  end
end
