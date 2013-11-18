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
end
