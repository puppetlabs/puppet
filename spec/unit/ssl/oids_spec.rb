require 'spec_helper'
require 'puppet/ssl/oids'

describe Puppet::SSL::Oids do
  describe "defining application OIDs" do

    {
      'puppetlabs' => '1.3.6.1.4.1.34380',
      'ppCertExt' => '1.3.6.1.4.1.34380.1',
      'ppRegCertExt' => '1.3.6.1.4.1.34380.1.1',
      'pp_uuid' => '1.3.6.1.4.1.34380.1.1.1',
      'pp_instance_id' => '1.3.6.1.4.1.34380.1.1.2',
      'pp_image_name' => '1.3.6.1.4.1.34380.1.1.3',
      'pp_preshared_key' => '1.3.6.1.4.1.34380.1.1.4',
      'ppPrivCertExt' => '1.3.6.1.4.1.34380.1.2',
    }.each_pair do |sn, oid|
      it "defines #{sn} as #{oid}" do
        object_id = OpenSSL::ASN1::ObjectId.new(sn)
        expect(object_id.oid).to eq oid
      end
    end
  end

  describe "checking if an OID is a subtree of another OID" do

    it "can determine if an OID is contained in another OID" do
      expect(described_class.subtree_of?('1.3.6.1', '1.3.6.1.4.1')).to be_truthy
      expect(described_class.subtree_of?('1.3.6.1.4.1', '1.3.6.1')).to be_falsey
    end

    it "returns true if an OID is compared against itself and exclusive is false" do
      expect(described_class.subtree_of?('1.3.6.1', '1.3.6.1', false)).to be_truthy
    end

    it "returns false if an OID is compared against itself and exclusive is true" do
      expect(described_class.subtree_of?('1.3.6.1', '1.3.6.1', true)).to be_falsey
    end

    it "can compare OIDs defined as short names" do
      expect(described_class.subtree_of?('IANA', '1.3.6.1.4.1')).to be_truthy
      expect(described_class.subtree_of?('1.3.6.1', 'enterprises')).to be_truthy
    end

    it "returns false when an invalid OID shortname is passed" do
      expect(described_class.subtree_of?('IANA', 'bananas')).to be_falsey
    end
  end
end
