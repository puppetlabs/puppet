require 'spec_helper'
require 'puppet/ssl/oids'

describe Puppet::SSL::Oids do
  describe "defining application OIDs" do

    {
      'puppetlabs'          => '1.3.6.1.4.1.34380',
      'ppCertExt'           => '1.3.6.1.4.1.34380.1',
      'ppRegCertExt'        => '1.3.6.1.4.1.34380.1.1',
      'pp_uuid'             => '1.3.6.1.4.1.34380.1.1.1',
      'pp_instance_id'      => '1.3.6.1.4.1.34380.1.1.2',
      'pp_image_name'       => '1.3.6.1.4.1.34380.1.1.3',
      'pp_preshared_key'    => '1.3.6.1.4.1.34380.1.1.4',
      'pp_cost_center'      => '1.3.6.1.4.1.34380.1.1.5',
      'pp_product'          => '1.3.6.1.4.1.34380.1.1.6',
      'pp_project'          => '1.3.6.1.4.1.34380.1.1.7',
      'pp_application'      => '1.3.6.1.4.1.34380.1.1.8',
      'pp_service'          => '1.3.6.1.4.1.34380.1.1.9',
      'pp_employee'         => '1.3.6.1.4.1.34380.1.1.10',
      'pp_created_by'       => '1.3.6.1.4.1.34380.1.1.11',
      'pp_environment'      => '1.3.6.1.4.1.34380.1.1.12',
      'pp_role'             => '1.3.6.1.4.1.34380.1.1.13',
      'pp_software_version' => '1.3.6.1.4.1.34380.1.1.14',
      'pp_department'       => '1.3.6.1.4.1.34380.1.1.15',
      'pp_cluster'          => '1.3.6.1.4.1.34380.1.1.16',
      'pp_provisioner'      => '1.3.6.1.4.1.34380.1.1.17',
      'pp_region'           => '1.3.6.1.4.1.34380.1.1.18',
      'pp_datacenter'       => '1.3.6.1.4.1.34380.1.1.19',
      'pp_zone'             => '1.3.6.1.4.1.34380.1.1.20',
      'pp_network'          => '1.3.6.1.4.1.34380.1.1.21',
      'pp_securitypolicy'   => '1.3.6.1.4.1.34380.1.1.22',
      'pp_cloudplatform'    => '1.3.6.1.4.1.34380.1.1.23',
      'pp_apptier'          => '1.3.6.1.4.1.34380.1.1.24',
      'pp_hostname'         => '1.3.6.1.4.1.34380.1.1.25',
      'ppPrivCertExt'       => '1.3.6.1.4.1.34380.1.2',
      'ppAuthCertExt'       => '1.3.6.1.4.1.34380.1.3',
      'pp_authorization'    => '1.3.6.1.4.1.34380.1.3.1',
      'pp_auth_role'        => '1.3.6.1.4.1.34380.1.3.13',
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
