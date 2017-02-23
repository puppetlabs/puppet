#! /usr/bin/env ruby -S rspec
# encoding: ASCII-8BIT
require 'spec_helper'

module Puppet::Util::Plist
end

describe Puppet::Type.type(:user).provider(:directoryservice) do
  let(:username) { 'nonexistent_user' }
  let(:user_path) { "/Users/#{username}" }
  let(:resource) do
    Puppet::Type.type(:user).new(
      :name     => username,
      :provider => :directoryservice
    )
  end
  let(:provider) { resource.provider }
  let(:users_plist_dir) { '/var/db/dslocal/nodes/Default/users' }

  # This is the output of doing `dscl -plist . read /Users/<username>` which
  # will return a hash of keys whose values are all arrays.
  let(:user_plist_xml) do
    '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
            <key>dsAttrTypeStandard:NFSHomeDirectory</key>
            <array>
            <string>/Users/nonexistent_user</string>
            </array>
            <key>dsAttrTypeStandard:RealName</key>
            <array>
            <string>nonexistent_user</string>
            </array>
            <key>dsAttrTypeStandard:PrimaryGroupID</key>
            <array>
            <string>22</string>
            </array>
            <key>dsAttrTypeStandard:UniqueID</key>
            <array>
            <string>1000</string>
            </array>
            <key>dsAttrTypeStandard:RecordName</key>
            <array>
            <string>nonexistent_user</string>
            </array>
    </dict>
    </plist>'
  end

  # This is the same as above, however in a native Ruby hash instead
  # of XML
  let(:user_plist_hash) do
    {
      "dsAttrTypeStandard:RealName"         => [username],
      "dsAttrTypeStandard:NFSHomeDirectory" => [user_path],
      "dsAttrTypeStandard:PrimaryGroupID"   => ["22"],
      "dsAttrTypeStandard:UniqueID"         => ["1000"],
      "dsAttrTypeStandard:RecordName"       => [username]
    }
  end

  let(:sha512_shadowhashdata_array) do
    ['62706c69 73743030 d101025d 53414c54 45442d53 48413531 324f1044 7ea7d592 131f57b2 c8f8bdbc '\
     'ec8d9df1 2128a386 393a4f00 c7619bac 2622a44d 451419d1 1da512d5 915ab98e 39718ac9 4083fe2e '\
     'fd6bf710 a54d477f 8ff735b1 2587192d 080b1900 00000000 00010100 00000000 00000300 00000000 '\
     '00000000 00000000 000060']
  end
  # The below value is the result of executing
  # `dscl -plist . read /Users/<username> ShadowHashData` on a 10.7
  # system and converting it to a native Ruby Hash with Plist.parse_xml
  let(:sha512_shadowhashdata_hash) do
    {
      'dsAttrTypeNative:ShadowHashData' => sha512_shadowhashdata_array
    }
  end

  # The below is a binary plist that is stored in the ShadowHashData key
  # on a 10.7 system.
  let(:sha512_embedded_bplist) do
    "bplist00\321\001\002]SALTED-SHA512O\020D~\247\325\222\023\037W\262\310\370\275\274\354\215\235\361!(\243\2069:O\000\307a\233\254&\"\244ME\024\031\321\035\245\022\325\221Z\271\2169q\212\311@\203\376.\375k\367\020\245MG\177\217\3675\261%\207\031-\b\v\031\000\000\000\000\000\000\001\001\000\000\000\000\000\000\000\003\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000`"
  end

  # The below is a Base64 encoded string representing a salted-SHA512 password
  # hash.
  let(:sha512_pw_string) do
    "~\247\325\222\023\037W\262\310\370\275\274\354\215\235\361!(\243\2069:O\000\307a\233\254&\"\244ME\024\031\321\035\245\022\325\221Z\271\2169q\212\311@\203\376.\375k\367\020\245MG\177\217\3675\261%\207\031-"
  end

  # The below is the result of converting sha512_embedded_bplist to XML and
  # parsing it with Plist.parse_xml. It is a Ruby Hash whose value is a
  # Base64 encoded salted-SHA512 password hash.
  let(:sha512_embedded_bplist_hash) do
    { 'SALTED-SHA512' => sha512_pw_string }
  end

  # The value below is the result of converting sha512_pw_string to Hex.
  let(:sha512_password_hash) do
    '7ea7d592131f57b2c8f8bdbcec8d9df12128a386393a4f00c7619bac2622a44d451419d11da512d5915ab98e39718ac94083fe2efd6bf710a54d477f8ff735b12587192d'
  end

  let(:pbkdf2_shadowhashdata_array) do
    ['62706c69 73743030 d101025f 10145341 4c544544 2d534841 3531322d 50424b44 4632d303 04050607 '\
     '0857656e 74726f70 79547361 6c745a69 74657261 74696f6e 734f1080 0590ade1 9e6953c1 35ae872a '\
     'e7761823 5df7d46c 63de7f9a 0fcdf2cd 9e7d85e4 b7ca8681 01235b61 58e05a30 9805ee48 14b027a4 '\
     'be9c23ec 2926bc81 72269aff ba5c9a59 85e81091 fa689807 6d297f1f aa75fa61 7551ef16 71d75200 '\
     '55c4a0d9 7b9b9c58 05aa322b aedbcd8e e9c52381 1653ac2e a9e9c8d8 f1ac519a 0f2b595e 4f102093 '\
     '77c46908 a1c8ac2c 3e45c0d4 4da8ad0f cd85ec5c 14d9a59f fc40c9da 31f0ec11 60b0080b 22293136 '\
     '41c4e700 00000000 00010100 00000000 00000900 00000000 00000000 00000000 0000ea']
  end
  # The below value is the result of executing
  # `dscl -plist . read /Users/<username> ShadowHashData` on a 10.8
  # system and converting it to a native Ruby Hash with Plist.parse_xml
  let(:pbkdf2_shadowhashdata_hash) do
    {
      "dsAttrTypeNative:ShadowHashData"=> pbkdf2_shadowhashdata_array
    }
  end

  # The below value is the result of converting pbkdf2_embedded_bplist to XML and
  # parsing it with Plist.parse_xml.
  let(:pbkdf2_embedded_bplist_hash) do
    {
      'SALTED-SHA512-PBKDF2' => {
        'entropy'    => pbkdf2_pw_string,
        'salt'       => pbkdf2_salt_string,
        'iterations' => pbkdf2_iterations_value
      }
    }
  end

  # The value below is the result of converting pbkdf2_pw_string to Hex.
  let(:pbkdf2_password_hash) do
    '0590ade19e6953c135ae872ae77618235df7d46c63de7f9a0fcdf2cd9e7d85e4b7ca868101235b6158e05a309805ee4814b027a4be9c23ec2926bc8172269affba5c9a5985e81091fa6898076d297f1faa75fa617551ef1671d7520055c4a0d97b9b9c5805aa322baedbcd8ee9c523811653ac2ea9e9c8d8f1ac519a0f2b595e'
  end

  # The below is a binary plist that is stored in the ShadowHashData key
  # of a 10.8 system.
  let(:pbkdf2_embedded_plist) do
    "bplist00\321\001\002_\020\024SALTED-SHA512-PBKDF2\323\003\004\005\006\a\bWentropyTsaltZiterationsO\020\200\005\220\255\341\236iS\3015\256\207*\347v\030#]\367\324lc\336\177\232\017\315\362\315\236}\205\344\267\312\206\201\001#[aX\340Z0\230\005\356H\024\260'\244\276\234#\354)&\274\201r&\232\377\272\\\232Y\205\350\020\221\372h\230\am)\177\037\252u\372auQ\357\026q\327R\000U\304\240\331{\233\234X\005\2522+\256\333\315\216\351\305#\201\026S\254.\251\351\310\330\361\254Q\232\017+Y^O\020 \223w\304i\b\241\310\254,>E\300\324M\250\255\017\315\205\354\\\024\331\245\237\374@\311\3321\360\354\021`\260\b\v\")16A\304\347\000\000\000\000\000\000\001\001\000\000\000\000\000\000\000\t\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\352"
  end

  # The below value is a Base64 encoded string representing a PBKDF2 password
  # hash.
  let(:pbkdf2_pw_string) do
    "\005\220\255\341\236iS\3015\256\207*\347v\030#]\367\324lc\336\177\232\017\315\362\315\236}\205\344\267\312\206\201\001#[aX\340Z0\230\005\356H\024\260'\244\276\234#\354)&\274\201r&\232\377\272\\\232Y\205\350\020\221\372h\230\am)\177\037\252u\372auQ\357\026q\327R\000U\304\240\331{\233\234X\005\2522+\256\333\315\216\351\305#\201\026S\254.\251\351\310\330\361\254Q\232\017+Y^"
  end

  # The below value is a Base64 encoded string representing a PBKDF2 salt
  # string.
  let(:pbkdf2_salt_string) do
    "\223w\304i\b\241\310\254,>E\300\324M\250\255\017\315\205\354\\\024\331\245\237\374@\311\3321\360\354"
  end

  # The below value represents the Hex value of a PBKDF2 salt string
  let(:pbkdf2_salt_value) do
    "9377c46908a1c8ac2c3e45c0d44da8ad0fcd85ec5c14d9a59ffc40c9da31f0ec"
  end

  # The below value is an Integer iterations value used in the PBKDF2
  # key stretching algorithm
  let(:pbkdf2_iterations_value) do
    24752
  end

  let(:pbkdf2_and_ssha512_shadowhashdata_array) do
    ['62706c69 73743030 d2010203 0a5f1014 53414c54 45442d53 48413531 322d5042 4b444632 5d53414c '\
     '5445442d 53484135 3132d304 05060708 0957656e 74726f70 79547361 6c745a69 74657261 74696f6e '\
     '734f1080 0590ade1 9e6953c1 35ae872a e7761823 5df7d46c 63de7f9a 0fcdf2cd 9e7d85e4 b7ca8681 '\
     '01235b61 58e05a30 9805ee48 14b027a4 be9c23ec 2926bc81 72269aff ba5c9a59 85e81091 fa689807 '\
     '6d297f1f aa75fa61 7551ef16 71d75200 55c4a0d9 7b9b9c58 05aa322b aedbcd8e e9c52381 1653ac2e '\
     'a9e9c8d8 f1ac519a 0f2b595e 4f102093 77c46908 a1c8ac2c 3e45c0d4 4da8ad0f cd85ec5c 14d9a59f '\
     'fc40c9da 31f0ec11 60b04f10 447ea7d5 92131f57 b2c8f8bd bcec8d9d f12128a3 86393a4f 00c7619b '\
     'ac2622a4 4d451419 d11da512 d5915ab9 8e39718a c94083fe 2efd6bf7 10a54d47 7f8ff735 b1258719 '\
     '2d000800 0d002400 32003900 41004600 5100d400 f700fa00 00000000 00020100 00000000 00000b00 '\
     '00000000 00000000 00000000 000141']
  end

  let(:pbkdf2_and_ssha512_shadowhashdata_hash) do
    {
      'dsAttrTypeNative:ShadowHashData' => pbkdf2_and_ssha512_shadowhashdata_array
    }
  end

  let (:pbkdf2_and_ssha512_embedded_plist) do
    "bplist00\xD2\x01\x02\x03\n_\x10\x14SALTED-SHA512-PBKDF2]SALTED-SHA512\xD3\x04\x05\x06\a\b\tWentropyTsaltZiterationsO\x10\x80\x05\x90\xAD\xE1\x9EiS\xC15\xAE\x87*\xE7v\x18#]\xF7\xD4lc\xDE\x7F\x9A\x0F\xCD\xF2\xCD\x9E}\x85\xE4\xB7\xCA\x86\x81\x01#[aX\xE0Z0\x98\x05\xEEH\x14\xB0'\xA4\xBE\x9C#\xEC)&\xBC\x81r&\x9A\xFF\xBA\\\x9AY\x85\xE8\x10\x91\xFAh\x98\am)\x7F\x1F\xAAu\xFAauQ\xEF\x16q\xD7R\x00U\xC4\xA0\xD9{\x9B\x9CX\x05\xAA2+\xAE\xDB\xCD\x8E\xE9\xC5#\x81\x16S\xAC.\xA9\xE9\xC8\xD8\xF1\xACQ\x9A\x0F+Y^O\x10 \x93w\xC4i\b\xA1\xC8\xAC,>E\xC0\xD4M\xA8\xAD\x0F\xCD\x85\xEC\\\x14\xD9\xA5\x9F\xFC@\xC9\xDA1\xF0\xEC\x11`\xB0O\x10D~\xA7\xD5\x92\x13\x1FW\xB2\xC8\xF8\xBD\xBC\xEC\x8D\x9D\xF1!(\xA3\x869:O\x00\xC7a\x9B\xAC&\"\xA4ME\x14\x19\xD1\x1D\xA5\x12\xD5\x91Z\xB9\x8E9q\x8A\xC9@\x83\xFE.\xFDk\xF7\x10\xA5MG\x7F\x8F\xF75\xB1%\x87\x19-\x00\b\x00\r\x00$\x002\x009\x00A\x00F\x00Q\x00\xD4\x00\xF7\x00\xFA\x00\x00\x00\x00\x00\x00\x02\x01\x00\x00\x00\x00\x00\x00\x00\v\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01A"
  end

  let (:pbkdf2_and_ssha512_embedded_bplist_hash) do
    {
      "SALTED-SHA512-PBKDF2" => {
        "entropy"     => pbkdf2_pw_string,
        "salt"        => pbkdf2_salt_value,
        "iterations"  => pbkdf2_iterations_value,
      },
      "SALTED-SHA512" => sha512_password_hash
    }
  end

  # The below represents output of 'dscl -plist . readall /Users' converted to
  # a native Ruby hash if only one user were installed on the system.
  # This lets us check the behavior of all the methods necessary to return a
  # user's groups property by controlling the data provided by dscl
  let(:testuser_base) do
    {
      "dsAttrTypeStandard:RecordName"             =>["nonexistent_user"],
      "dsAttrTypeStandard:UniqueID"               =>["1000"],
      "dsAttrTypeStandard:AuthenticationAuthority"=>
       [";Kerberosv5;;testuser@LKDC:SHA1.4383E152D9D394AA32D13AE98F6F6E1FE8D00F81;LKDC:SHA1.4383E152D9D394AA32D13AE98F6F6E1FE8D00F81",
        ";ShadowHash;HASHLIST:<SALTED-SHA512>"],
      "dsAttrTypeStandard:AppleMetaNodeLocation"  =>["/Local/Default"],
      "dsAttrTypeStandard:NFSHomeDirectory"       =>["/Users/nonexistent_user"],
      "dsAttrTypeStandard:RecordType"             =>["dsRecTypeStandard:Users"],
      "dsAttrTypeStandard:RealName"               =>["nonexistent_user"],
      "dsAttrTypeStandard:Password"               =>["********"],
      "dsAttrTypeStandard:PrimaryGroupID"         =>["22"],
      "dsAttrTypeStandard:GeneratedUID"           =>["0A7D5B63-3AD4-4CA7-B03E-85876F1D1FB3"],
      "dsAttrTypeStandard:AuthenticationHint"     =>[""],
      "dsAttrTypeNative:KerberosKeys"             =>
       ["30820157 a1030201 02a08201 4e308201 4a3074a1 2b3029a0 03020112 a1220420 54af3992 1c198bf8 94585a6b 2fba445b c8482228 0dcad666 ea62e038 99e59c45 a2453043 a0030201 03a13c04 3a4c4b44 433a5348 41312e34 33383345 31353244 39443339 34414133 32443133 41453938 46364636 45314645 38443030 46383174 65737475 73657230 64a11b30 19a00302 0111a112 04106375 7d97b2ce ca8343a6 3b0f73d5 1001a245 3043a003 020103a1 3c043a4c 4b44433a 53484131 2e343338 33453135 32443944 33393441 41333244 31334145 39384636 46364531 46453844 30304638 31746573 74757365 72306ca1 233021a0 03020110 a11a0418 67b09be3 5131b670 f8e9265e 62459b4c 19435419 fe918519 a2453043 a0030201 03a13c04 3a4c4b44 433a5348 41312e34 33383345 31353244 39443339 34414133 32443133 41453938 46364636 45314645 38443030 46383174 65737475 736572"],
      "dsAttrTypeStandard:PasswordPolicyOptions"  =>
       ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n          <!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n          <plist version=\"1.0\">\n          <dict>\n            <key>failedLoginCount</key>\n            <integer>0</integer>\n            <key>failedLoginTimestamp</key>\n            <date>2001-01-01T00:00:00Z</date>\n            <key>lastLoginTimestamp</key>\n            <date>2001-01-01T00:00:00Z</date>\n            <key>passwordTimestamp</key>\n            <date>2012-08-10T23:53:50Z</date>\n          </dict>\n          </plist>\n          "],
      "dsAttrTypeStandard:UserShell"              =>["/bin/bash"],
      "dsAttrTypeNative:ShadowHashData"           =>
       ["62706c69 73743030 d101025d 53414c54 45442d53 48413531 324f1044 7ea7d592 131f57b2 c8f8bdbc ec8d9df1 2128a386 393a4f00 c7619bac 2622a44d 451419d1 1da512d5 915ab98e 39718ac9 4083fe2e fd6bf710 a54d477f 8ff735b1 2587192d 080b1900 00000000 00010100 00000000 00000300 00000000 00000000 00000000 000060"]
     }
  end
  let(:testuser_hash) do
    [
      testuser_base.merge(sha512_shadowhashdata_hash),
      testuser_base.merge(pbkdf2_shadowhashdata_hash),
    ]
  end

  # The below represents the result of running Plist.parse_xml on XML
  # data returned from the `dscl -plist . readall /Groups` command.
  # (AKA: What the get_list_of_groups method returns)
  let(:group_plist_hash_guid) do
    [{
      'dsAttrTypeStandard:RecordName'      => ['testgroup'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                username,
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                "guid#{username}",
                                                'guidtestuser',
                                                'guidjeff',
                                                'guidzack'
                                              ],
    },
    {
      'dsAttrTypeStandard:RecordName'      => ['second'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                "guid#{username}",
                                                'guidjeff',
                                                'guidzack'
                                              ],
    },
    {
      'dsAttrTypeStandard:RecordName'      => ['third'],
      'dsAttrTypeStandard:GroupMembership' => [
                                                username,
                                                'jeff',
                                                'zack'
                                              ],
      'dsAttrTypeStandard:GroupMembers'    => [
                                                "guid#{username}",
                                                'guidtestuser',
                                                'guidjeff',
                                                'guidzack'
                                              ],
    }]
  end


  describe 'Creating a user that does not exist' do
    # These are the defaults that the provider will use if a user does
    # not provide a value
    let(:defaults) do
      {
        'UniqueID'         => '1000',
        'RealName'         => resource[:name],
        'PrimaryGroupID'   => 20,
        'UserShell'        => '/bin/bash',
        'NFSHomeDirectory' => "/Users/#{resource[:name]}"
      }
    end

    before :each do
      # Stub out all calls to dscl with default values from above
      defaults.each do |key, val|
        provider.stubs(:merge_attribute_with_dscl).with('Users', username, key, val)
      end

      # Mock the rest of the dscl calls. We can't assume that our Linux
      # build system will have the dscl binary
      provider.stubs(:create_new_user).with(username)
      provider.class.stubs(:get_attribute_from_dscl).with('Users', username, 'GeneratedUID').returns({'dsAttrTypeStandard:GeneratedUID' => ['GUID']})
      provider.stubs(:next_system_id).returns('1000')
    end

    it 'should not raise any errors when creating a user with default values' do
      provider.create
    end

    %w{password iterations salt}.each do |value|
      it "should call ##{value}= if a #{value} attribute is specified" do
        resource[value.intern] = 'somevalue'
        setter = (value << '=').intern
        provider.expects(setter).with('somevalue')
        provider.create
      end
    end

    it 'should merge the GroupMembership and GroupMembers dscl values if a groups attribute is specified' do
      resource[:groups] = 'somegroup'
      provider.expects(:merge_attribute_with_dscl).with('Groups', 'somegroup', 'GroupMembership', username)
      provider.expects(:merge_attribute_with_dscl).with('Groups', 'somegroup', 'GroupMembers', 'GUID')
      provider.create
    end

    it 'should convert group names into integers' do
      resource[:gid] = 'somegroup'
      Puppet::Util.expects(:gid).with('somegroup').returns(21)
      provider.expects(:merge_attribute_with_dscl).with('Users', username, 'PrimaryGroupID', 21)
      provider.create
    end
  end

  describe 'self#instances' do
    it 'should create an array of provider instances' do
      provider.class.expects(:get_all_users).returns(['foo', 'bar'])
      ['foo', 'bar'].each do |user|
        provider.class.expects(:generate_attribute_hash).with(user).returns({})
      end
      instances = provider.class.instances

      expect(instances).to be_a_kind_of Array
      instances.each do |instance|
        expect(instance).to be_a_kind_of Puppet::Provider
      end
    end
  end

  describe 'self#get_all_users', :if => Puppet.features.cfpropertylist? do
    let(:empty_plist) do
      '<?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
      </dict>
      </plist>'
    end

    it 'should return a hash of user attributes' do
      provider.class.expects(:dscl).with('-plist', '.', 'readall', '/Users').returns(user_plist_xml)
      expect(provider.class.get_all_users).to eq(user_plist_hash)
    end

    it 'should return a hash when passed an empty plist' do
      provider.class.expects(:dscl).with('-plist', '.', 'readall', '/Users').returns(empty_plist)
      expect(provider.class.get_all_users).to eq({})
    end
  end

  describe 'self#generate_attribute_hash' do
    let(:user_plist_resource) do
      {
        :ensure         => :present,
        :provider       => :directoryservice,
        :groups         => 'testgroup,third',
        :comment        => username,
        :password       => sha512_password_hash,
        :shadowhashdata => sha512_shadowhashdata_array,
        :name           => username,
        :uid            => 1000,
        :gid            => 22,
        :home           => user_path
      }
    end

    before :each do
      provider.class.stubs(:get_os_version).returns('10.7')
      provider.class.stubs(:get_all_users).returns(testuser_hash)
      provider.class.stubs(:get_list_of_groups).returns(group_plist_hash_guid)
      provider.class.stubs(:convert_binary_to_hash).with(sha512_embedded_bplist).returns(sha512_embedded_bplist_hash)
      provider.class.stubs(:convert_binary_to_hash).with(pbkdf2_embedded_plist).returns(pbkdf2_embedded_bplist_hash)
      provider.class.prefetch({})
    end

    it 'should return :uid values as an Integer' do
      expect(provider.class.generate_attribute_hash(user_plist_hash)[:uid]).to be_a Integer
    end

    it 'should return :gid values as an Integer' do
      expect(provider.class.generate_attribute_hash(user_plist_hash)[:gid]).to be_a Integer
    end

    it 'should return a hash of resource attributes' do
      expect(provider.class.generate_attribute_hash(user_plist_hash.merge(sha512_shadowhashdata_hash))).to eq(user_plist_resource)
    end
  end

  describe 'self#generate_attribute_hash with pbkdf2 and ssha512' do
    let(:user_plist_resource) do
      {
        :ensure         => :present,
        :provider       => :directoryservice,
        :groups         => 'testgroup,third',
        :comment        => username,
        :password       => pbkdf2_password_hash,
        :iterations     => pbkdf2_iterations_value,
        :salt           => pbkdf2_salt_value,
        :shadowhashdata => pbkdf2_and_ssha512_shadowhashdata_array,
        :name           => username,
        :uid            => 1000,
        :gid            => 22,
        :home           => user_path
      }
    end

    before :each do
      provider.class.stubs(:get_os_version).returns('10.7')
      provider.class.stubs(:get_all_users).returns(testuser_hash)
      provider.class.stubs(:get_list_of_groups).returns(group_plist_hash_guid)
      provider.class.prefetch({})
    end

    it 'should return a hash of resource attributes' do
      expect(provider.class.generate_attribute_hash(user_plist_hash.merge(pbkdf2_and_ssha512_shadowhashdata_hash))).to eq(user_plist_resource)
    end

  end

  describe 'self#generate_attribute_hash empty shadowhashdata' do
    let(:user_plist_resource) do
      {
        :ensure         => :present,
        :provider       => :directoryservice,
        :groups         => 'testgroup,third',
        :comment        => username,
        :password       => '*',
        :shadowhashdata => nil,
        :name           => username,
        :uid            => 1000,
        :gid            => 22,
        :home           => user_path
      }
    end

    it 'should handle empty shadowhashdata' do
      provider.class.stubs(:get_os_version).returns('10.7')
      provider.class.stubs(:get_all_users).returns([testuser_base])
      provider.class.stubs(:get_list_of_groups).returns(group_plist_hash_guid)
      provider.class.prefetch({})
      expect(provider.class.generate_attribute_hash(user_plist_hash)).to eq(user_plist_resource)
    end
  end

  describe '#delete' do
    it 'should call dscl when destroying/deleting a resource' do
      provider.expects(:dscl).with('.', '-delete', user_path)
      provider.delete
    end
  end

  describe 'the groups property' do
    # The below represents the result of running Plist.parse_xml on XML
    # data returned from the `dscl -plist . readall /Groups` command.
    # (AKA: What the get_list_of_groups method returns)
    let(:group_plist_hash) do
      [{
        'dsAttrTypeStandard:RecordName'      => ['testgroup'],
        'dsAttrTypeStandard:GroupMembership' => [
                                                  'testuser',
                                                  username,
                                                  'jeff',
                                                  'zack'
                                                ],
        'dsAttrTypeStandard:GroupMembers'    => [
                                                  'guidtestuser',
                                                  'guidjeff',
                                                  'guidzack'
                                                ],
      },
      {
        'dsAttrTypeStandard:RecordName'      => ['second'],
        'dsAttrTypeStandard:GroupMembership' => [
                                                  username,
                                                  'testuser',
                                                  'jeff',
                                                ],
        'dsAttrTypeStandard:GroupMembers'    => [
                                                  'guidtestuser',
                                                  'guidjeff',
                                                ],
      },
      {
        'dsAttrTypeStandard:RecordName'      => ['third'],
        'dsAttrTypeStandard:GroupMembership' => [
                                                  'jeff',
                                                  'zack'
                                                ],
        'dsAttrTypeStandard:GroupMembers'    => [
                                                  'guidjeff',
                                                  'guidzack'
                                                ],
      }]
    end


    before :each do
      provider.class.stubs(:get_all_users).returns(testuser_hash)
      provider.class.stubs(:get_os_version).returns('10.7')
    end

    it "should return a list of groups if the user's name matches GroupMembership" do
      provider.class.expects(:get_list_of_groups).returns(group_plist_hash)
      provider.class.expects(:get_list_of_groups).returns(group_plist_hash)
      expect(provider.class.prefetch({}).first.groups).to eq('second,testgroup')
    end

    it "should return a list of groups if the user's GUID matches GroupMembers" do
      provider.class.expects(:get_list_of_groups).returns(group_plist_hash_guid)
      provider.class.expects(:get_list_of_groups).returns(group_plist_hash_guid)
      expect(provider.class.prefetch({}).first.groups).to eq('testgroup,third')
    end
  end

  describe '#groups=' do
    let(:group_plist_one_two_three) do
      [{
        'dsAttrTypeStandard:RecordName'      => ['one'],
        'dsAttrTypeStandard:GroupMembership' => [
                                                  'jeff',
                                                  'zack'
                                                ],
        'dsAttrTypeStandard:GroupMembers'    => [
                                                  'guidjeff',
                                                  'guidzack'
                                                ],
      },
      {
        'dsAttrTypeStandard:RecordName'      => ['two'],
        'dsAttrTypeStandard:GroupMembership' => [
                                                  'jeff',
                                                  'zack',
                                                  username
                                                ],
        'dsAttrTypeStandard:GroupMembers'    => [
                                                  'guidjeff',
                                                  'guidzack'
                                                ],
      },
      {
        'dsAttrTypeStandard:RecordName'      => ['three'],
        'dsAttrTypeStandard:GroupMembership' => [
                                                  'jeff',
                                                  'zack',
                                                  username
                                                ],
        'dsAttrTypeStandard:GroupMembers'    => [
                                                  'guidjeff',
                                                  'guidzack'
                                                ],
      }]
    end

    before :each do
      provider.class.stubs(:get_all_users).returns(testuser_hash)
      provider.class.stubs(:get_list_of_groups).returns(group_plist_one_two_three)
    end

    it 'should call dscl to add necessary groups' do
      provider.class.expects(:get_attribute_from_dscl).with('Users', username, 'GeneratedUID').returns({'dsAttrTypeStandard:GeneratedUID' => ['guidnonexistent_user']})
      provider.expects(:groups).returns('two,three')
      provider.expects(:dscl).with('.', '-merge', '/Groups/one', 'GroupMembership', 'nonexistent_user')
      provider.expects(:dscl).with('.', '-merge', '/Groups/one', 'GroupMembers', 'guidnonexistent_user')
      provider.class.prefetch({})
      provider.groups= 'one,two,three'
    end

    it 'should call the get_salted_sha512 method on 10.7 and return the correct hash' do
      provider.class.expects(:convert_binary_to_hash).with(sha512_embedded_bplist).returns(sha512_embedded_bplist_hash)
      provider.class.expects(:convert_binary_to_hash).with(pbkdf2_embedded_plist).returns(pbkdf2_embedded_bplist_hash)
      expect(provider.class.prefetch({}).first.password).to eq(sha512_password_hash)
    end

    it 'should call the get_salted_sha512_pbkdf2 method on 10.8 and return the correct hash' do
      provider.class.expects(:convert_binary_to_hash).with(sha512_embedded_bplist).returns(sha512_embedded_bplist_hash)
      provider.class.expects(:convert_binary_to_hash).with(pbkdf2_embedded_plist).returns(pbkdf2_embedded_bplist_hash)
      expect(provider.class.prefetch({}).last.password).to eq(pbkdf2_password_hash)
    end

  end

  describe '#password=' do
    before :each do
      provider.stubs(:sleep)
      provider.stubs(:flush_dscl_cache)
    end

    it 'should call write_password_to_users_plist when setting the password' do
      provider.class.stubs(:get_os_version).returns('10.7')
      provider.expects(:write_password_to_users_plist).with(sha512_password_hash)
      provider.password = sha512_password_hash
    end

    it 'should call write_password_to_users_plist when setting the password' do
      provider.class.stubs(:get_os_version).returns('10.8')
      resource[:salt] = pbkdf2_salt_value
      resource[:iterations] = pbkdf2_iterations_value
      resource[:password] = pbkdf2_password_hash

      provider.expects(:write_password_to_users_plist).with(pbkdf2_password_hash)

      provider.password = resource[:password]
    end


    it "should raise an error on 10.7 if a password hash that doesn't contain 136 characters is passed" do
      provider.class.stubs(:get_os_version).returns('10.7')
      expect { provider.password = 'password' }.to raise_error Puppet::Error, /OS X 10\.7 requires a Salted SHA512 hash password of 136 characters\.  Please check your password and try again/
    end
  end

  describe "passwords on 10.8" do
    before :each do
      provider.class.stubs(:get_os_version).returns('10.8')
    end

    it "should raise an error on 10.8 if a password hash that doesn't contain 256 characters is passed" do
      expect do
        provider.password = 'password'
      end.to raise_error(Puppet::Error, /OS X versions > 10\.7 require a Salted SHA512 PBKDF2 password hash of 256 characters\. Please check your password and try again\./)
    end

    it "fails if a password is given but not salt and iterations" do
      resource[:password] = pbkdf2_password_hash

      expect do
        provider.password = resource[:password]
      end.to raise_error(Puppet::Error, /OS X versions > 10\.7 use PBKDF2 password hashes, which requires all three of salt, iterations, and password hash\. This resource is missing: salt, iterations\./)
    end

    it "fails if salt is given but not password and iterations" do
      resource[:salt] = pbkdf2_salt_value

      expect do
        provider.salt = resource[:salt]
      end.to raise_error(Puppet::Error, /OS X versions > 10\.7 use PBKDF2 password hashes, which requires all three of salt, iterations, and password hash\. This resource is missing: password, iterations\./)
    end

    it "fails if iterations is given but not password and salt" do
      resource[:iterations] = pbkdf2_iterations_value

      expect do
        provider.iterations = resource[:iterations]
      end.to raise_error(Puppet::Error, /OS X versions > 10\.7 use PBKDF2 password hashes, which requires all three of salt, iterations, and password hash\. This resource is missing: password, salt\./)
    end
  end

  describe '#get_list_of_groups', :if => Puppet.features.cfpropertylist? do
    # The below value is the result of running `dscl -plist . readall /Groups`
    # on an OS X system.
    let(:groups_xml) do
      '<?xml version="1.0" encoding="UTF-8"?>
       <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
       <plist version="1.0">
       <array>
         <dict>
           <key>dsAttrTypeStandard:AppleMetaNodeLocation</key>
           <array>
             <string>/Local/Default</string>
           </array>
           <key>dsAttrTypeStandard:GeneratedUID</key>
           <array>
             <string>ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000053</string>
           </array>
           <key>dsAttrTypeStandard:Password</key>
           <array>
             <string>*</string>
           </array>
           <key>dsAttrTypeStandard:PrimaryGroupID</key>
           <array>
             <string>83</string>
           </array>
           <key>dsAttrTypeStandard:RealName</key>
           <array>
             <string>SPAM Assassin Group 2</string>
           </array>
           <key>dsAttrTypeStandard:RecordName</key>
           <array>
             <string>_amavisd</string>
             <string>amavisd</string>
           </array>
           <key>dsAttrTypeStandard:RecordType</key>
           <array>
             <string>dsRecTypeStandard:Groups</string>
           </array>
         </dict>
        </array>
      </plist>'
    end

    # The below value is the result of executing Plist.parse_xml on
    # groups_xml
    let(:groups_hash) do
      [{ 'dsAttrTypeStandard:AppleMetaNodeLocation' => ['/Local/Default'],
           'dsAttrTypeStandard:GeneratedUID'          => ['ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000053'],
           'dsAttrTypeStandard:Password'              => ['*'],
           'dsAttrTypeStandard:PrimaryGroupID'        => ['83'],
           'dsAttrTypeStandard:RealName'              => ['SPAM Assassin Group 2'],
           'dsAttrTypeStandard:RecordName'            => ['_amavisd', 'amavisd'],
           'dsAttrTypeStandard:RecordType'            => ['dsRecTypeStandard:Groups']
        }]
    end

    before :each do
      # Ensure we don't have a value cached from another spec
      provider.class.instance_variable_set(:@groups, nil) if provider.class.instance_variable_defined? :@groups
    end

    it 'should return an array of hashes containing group data' do
      provider.class.expects(:dscl).with('-plist', '.', 'readall', '/Groups').returns(groups_xml)
      expect(provider.class.get_list_of_groups).to eq(groups_hash)
    end
  end

  describe '#get_attribute_from_dscl', :if => Puppet.features.cfpropertylist? do
    # The below value is the result of executing
    # `dscl -plist . read /Users/<username/ GeneratedUID`
    # on an OS X system.
    let(:user_guid_xml) do
      '<?xml version="1.0" encoding="UTF-8"?>
       <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
       <plist version="1.0">
       <dict>
         <key>dsAttrTypeStandard:GeneratedUID</key>
         <array>
           <string>DCC660C6-F5A9-446D-B9FF-3C0258AB5BA0</string>
         </array>
       </dict>
       </plist>'
    end

    # The below value is the result of parsing user_guid_xml with
    # Plist.parse_xml
    let(:user_guid_hash) do
      { 'dsAttrTypeStandard:GeneratedUID' => ['DCC660C6-F5A9-446D-B9FF-3C0258AB5BA0'] }
    end

    it 'should return a hash containing a user\'s dscl attribute data' do
      provider.class.expects(:dscl).with('-plist', '.', 'read', user_path, 'GeneratedUID').returns(user_guid_xml)
      expect(provider.class.get_attribute_from_dscl('Users', username, 'GeneratedUID')).to eq(user_guid_hash)
    end
  end

  describe '#convert_hash_to_binary' do
    it 'should use plutil to successfully convert an xml plist to a binary plist' do
      Puppet::Util::Plist.expects(:dump_plist).with('ruby_hash', :binary).returns('binary_plist_data')
      expect(provider.class.convert_hash_to_binary('ruby_hash')).to eq('binary_plist_data')
    end
  end

  describe '#convert_binary_to_hash' do
    it 'should accept a binary plist and return a ruby hash containing the plist data' do
      Puppet::Util::Plist.expects(:parse_plist).with('binary_plist_data').returns(user_plist_hash)
      expect(provider.class.convert_binary_to_hash('binary_plist_data')).to eq(user_plist_hash)
    end
  end

  describe '#next_system_id' do
    it 'should return the next available UID number that is not in the list obtained from dscl and is greater than the passed integer value' do
      provider.expects(:dscl).with('.', '-list', '/Users', 'uid').returns("kathee 312\ngary 11\ntanny 33\njohn 9\nzach 5")
      expect(provider.next_system_id(30)).to eq(34)
    end
  end

  describe '#get_salted_sha512' do
    it "should accept a hash whose 'SALTED-SHA512' key contains a base64 encoded salted-SHA512 password hash and return the hex value of that password hash" do
      expect(provider.class.get_salted_sha512(sha512_embedded_bplist_hash)).to eq(sha512_password_hash)
    end
  end

  describe '#get_salted_sha512_pbkdf2' do
    it "should accept a hash containing a PBKDF2 password hash, salt, and iterations value and return the correct password hash" do
        expect(provider.class.get_salted_sha512_pbkdf2('entropy', pbkdf2_embedded_bplist_hash)).to eq(pbkdf2_password_hash)
    end
    it "should accept a hash containing a PBKDF2 password hash, salt, and iterations value and return the correct salt value" do
        expect(provider.class.get_salted_sha512_pbkdf2('salt', pbkdf2_embedded_bplist_hash)).to eq(pbkdf2_salt_value)
    end
    it "should accept a hash containing a PBKDF2 password hash, salt, and iterations value and return the correct iterations value" do
        expect(provider.class.get_salted_sha512_pbkdf2('iterations', pbkdf2_embedded_bplist_hash)).to eq(pbkdf2_iterations_value)
    end
    it "should return an Integer value when looking up the PBKDF2 iterations value" do
        expect(provider.class.get_salted_sha512_pbkdf2('iterations', pbkdf2_embedded_bplist_hash)).to be_a(Integer)
    end
    it "should raise an error if a field other than 'entropy', 'salt', or 'iterations' is passed" do
      expect { provider.class.get_salted_sha512_pbkdf2('othervalue', pbkdf2_embedded_bplist_hash) }.to raise_error(Puppet::Error, /Puppet has tried to read an incorrect value from the SALTED-SHA512-PBKDF2 hash. Acceptable fields are 'salt', 'entropy', or 'iterations'/)
    end
  end

  describe '#get_sha1' do
    let(:password_hash_file) { '/var/db/shadow/hash/user_guid' }
    let(:stub_password_file) { stub('connection') }

    it 'should return a sha1 hash read from disk' do
      Puppet::FileSystem.expects(:exist?).with(password_hash_file).returns(true)
      File.expects(:file?).with(password_hash_file).returns(true)
      File.expects(:readable?).with(password_hash_file).returns(true)
      File.expects(:new).with(password_hash_file).returns(stub_password_file)
      stub_password_file.expects(:read).returns('sha1_password_hash')
      stub_password_file.expects(:close)
      expect(provider.class.get_sha1('user_guid')).to eq('sha1_password_hash')
    end

    it 'should return nil if the password_hash_file does not exist' do
      Puppet::FileSystem.expects(:exist?).with(password_hash_file).returns(false)
      expect(provider.class.get_sha1('user_guid')).to eq(nil)
    end

    it 'should return nil if the password_hash_file is not a file' do
      Puppet::FileSystem.expects(:exist?).with(password_hash_file).returns(true)
      File.expects(:file?).with(password_hash_file).returns(false)
      expect(provider.class.get_sha1('user_guid')).to eq(nil)
    end

    it 'should raise an error if the password_hash_file is not readable' do
      Puppet::FileSystem.expects(:exist?).with(password_hash_file).returns(true)
      File.expects(:file?).with(password_hash_file).returns(true)
      File.expects(:readable?).with(password_hash_file).returns(false)
      expect { expect(provider.class.get_sha1('user_guid')).to eq(nil) }.to raise_error(Puppet::Error, /Could not read password hash file at #{password_hash_file}/)
    end
  end

  describe '#write_password_to_users_plist' do
    let(:sha512_plist_xml) do
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>KerberosKeys</key>\n\t<array>\n\t\t<data>\n\t\tMIIBS6EDAgEBoIIBQjCCAT4wcKErMCmgAwIBEqEiBCCS/0Im7BAps/YhX/ED\n\t\tKOpDeSMFkUsu3UzEa6gqDu35BKJBMD+gAwIBA6E4BDZMS0RDOlNIQTEuNDM4\n\t\tM0UxNTJEOUQzOTRBQTMyRDEzQUU5OEY2RjZFMUZFOEQwMEY4MWplZmYwYKEb\n\t\tMBmgAwIBEaESBBAk8a3rrFk5mHAdEU5nRgFwokEwP6ADAgEDoTgENkxLREM6\n\t\tU0hBMS40MzgzRTE1MkQ5RDM5NEFBMzJEMTNBRTk4RjZGNkUxRkU4RDAwRjgx\n\t\tamVmZjBooSMwIaADAgEQoRoEGFg71irsV+9ddRNPSn9houo3Q6jZuj55XaJB\n\t\tMD+gAwIBA6E4BDZMS0RDOlNIQTEuNDM4M0UxNTJEOUQzOTRBQTMyRDEzQUU5\n\t\tOEY2RjZFMUZFOEQwMEY4MWplZmY=\n\t\t</data>\n\t</array>\n\t<key>ShadowHashData</key>\n\t<array>\n\t\t<data>\n\t\tYnBsaXN0MDDRAQJdU0FMVEVELVNIQTUxMk8QRFNL0iuruijP6becUWe43GTX\n\t\t5WTgOTi2emx41DMnwnB4vbKieVOE4eNHiyocX5c0GX1LWJ6VlZqZ9EnDLsuA\n\t\tNC5Ga9qlCAsZAAAAAAAAAQEAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAGA=\n\t\t</data>\n\t</array>\n\t<key>authentication_authority</key>\n\t<array>\n\t\t<string>;Kerberosv5;;jeff@LKDC:SHA1.4383E152D9D394AA32D13AE98F6F6E1FE8D00F81;LKDC:SHA1.4383E152D9D394AA32D13AE98F6F6E1FE8D00F81</string>\n\t\t<string>;ShadowHash;HASHLIST:&lt;SALTED-SHA512&gt;</string>\n\t</array>\n\t<key>dsAttrTypeStandard:ShadowHashData</key>\n\t<array>\n\t\t<data>\n\t\tYnBsaXN0MDDRAQJdU0FMVEVELVNIQTUxMk8QRH6n1ZITH1eyyPi9vOyNnfEh\n\t\tKKOGOTpPAMdhm6wmIqRNRRQZ0R2lEtWRWrmOOXGKyUCD/i79a/cQpU1Hf4/3\n\t\tNbElhxktCAsZAAAAAAAAAQEAAAAAAAAAAwAAAAAAAAAAAAAAAAAAAGA=\n\t\t</data>\n\t</array>\n\t<key>generateduid</key>\n\t<array>\n\t\t<string>3AC74939-C14F-45DD-B6A9-D1A82373F0B0</string>\n\t</array>\n\t<key>name</key>\n\t<array>\n\t\t<string>jeff</string>\n\t</array>\n\t<key>passwd</key>\n\t<array>\n\t\t<string>********</string>\n\t</array>\n\t<key>passwordpolicyoptions</key>\n\t<array>\n\t\t<data>\n\t\tPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NU\n\t\tWVBFIHBsaXN0IFBVQkxJQyAiLS8vQXBwbGUvL0RURCBQTElTVCAxLjAvL0VO\n\t\tIiAiaHR0cDovL3d3dy5hcHBsZS5jb20vRFREcy9Qcm9wZXJ0eUxpc3QtMS4w\n\t\tLmR0ZCI+CjxwbGlzdCB2ZXJzaW9uPSIxLjAiPgo8ZGljdD4KCTxrZXk+ZmFp\n\t\tbGVkTG9naW5Db3VudDwva2V5PgoJPGludGVnZXI+MDwvaW50ZWdlcj4KCTxr\n\t\tZXk+ZmFpbGVkTG9naW5UaW1lc3RhbXA8L2tleT4KCTxkYXRlPjIwMDEtMDEt\n\t\tMDFUMDA6MDA6MDBaPC9kYXRlPgoJPGtleT5sYXN0TG9naW5UaW1lc3RhbXA8\n\t\tL2tleT4KCTxkYXRlPjIwMDEtMDEtMDFUMDA6MDA6MDBaPC9kYXRlPgoJPGtl\n\t\teT5wYXNzd29yZFRpbWVzdGFtcDwva2V5PgoJPGRhdGU+MjAxMi0wOC0xMVQw\n\t\tMDozNTo1MFo8L2RhdGU+CjwvZGljdD4KPC9wbGlzdD4K\n\t\t</data>\n\t</array>\n\t<key>uid</key>\n\t<array>\n\t\t<string>28</string>\n\t</array>\n</dict>\n</plist>"
    end

    let(:pbkdf2_plist_xml) do
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>KerberosKeys</key>\n\t<array>\n\t\t<data>\n\t\tMIIBS6EDAgEBoIIBQjCCAT4wcKErMCmgAwIBEqEiBCDrboPy0gxu7oTZR/Pc\n\t\tYdCBC9ivXo1k05gt036/aNe5VqJBMD+gAwIBA6E4BDZMS0RDOlNIQTEuNDEz\n\t\tQTMwRjU5MEVFREM3ODdENTMyOTgxODUwQTk3NTI0NUIwQTcyM2plZmYwYKEb\n\t\tMBmgAwIBEaESBBCm02SYYdsxo2fiDP4KuPtmokEwP6ADAgEDoTgENkxLREM6\n\t\tU0hBMS40MTNBMzBGNTkwRUVEQzc4N0Q1MzI5ODE4NTBBOTc1MjQ1QjBBNzIz\n\t\tamVmZjBooSMwIaADAgEQoRoEGHPBc7Dg7zjaE8g+YXObwupiBLMIlCrN5aJB\n\t\tMD+gAwIBA6E4BDZMS0RDOlNIQTEuNDEzQTMwRjU5MEVFREM3ODdENTMyOTgx\n\t\tODUwQTk3NTI0NUIwQTcyM2plZmY=\n\t\t</data>\n\t</array>\n\t<key>ShadowHashData</key>\n\t<array>\n\t\t<data>\n\t\tYnBsaXN0MDDRAQJfEBRTQUxURUQtU0hBNTEyLVBCS0RGMtMDBAUGBwhXZW50\n\t\tcm9weVRzYWx0Wml0ZXJhdGlvbnNPEIAFkK3hnmlTwTWuhyrndhgjXffUbGPe\n\t\tf5oPzfLNnn2F5LfKhoEBI1thWOBaMJgF7kgUsCekvpwj7CkmvIFyJpr/ulya\n\t\tWYXoEJH6aJgHbSl/H6p1+mF1Ue8WcddSAFXEoNl7m5xYBaoyK67bzY7pxSOB\n\t\tFlOsLqnpyNjxrFGaDytZXk8QIJN3xGkIocisLD5FwNRNqK0PzYXsXBTZpZ/8\n\t\tQMnaMfDsEWCwCAsiKTE2QcTnAAAAAAAAAQEAAAAAAAAACQAAAAAAAAAAAAAA\n\t\tAAAAAOo=\n\t\t</data>\n\t</array>\n\t<key>authentication_authority</key>\n\t<array>\n\t\t<string>;Kerberosv5;;jeff@LKDC:SHA1.413A30F590EEDC787D532981850A975245B0A723;LKDC:SHA1.413A30F590EEDC787D532981850A975245B0A723</string>\n\t\t<string>;ShadowHash;HASHLIST:&lt;SALTED-SHA512-PBKDF2&gt;</string>\n\t</array>\n\t<key>generateduid</key>\n\t<array>\n\t\t<string>1CB825D1-2DF7-43CC-B874-DB6BBB76C402</string>\n\t</array>\n\t<key>gid</key>\n\t<array>\n\t\t<string>21</string>\n\t</array>\n\t<key>name</key>\n\t<array>\n\t\t<string>jeff</string>\n\t</array>\n\t<key>passwd</key>\n\t<array>\n\t\t<string>********</string>\n\t</array>\n\t<key>passwordpolicyoptions</key>\n\t<array>\n\t\t<data>\n\t\tPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NU\n\t\tWVBFIHBsaXN0IFBVQkxJQyAiLS8vQXBwbGUvL0RURCBQTElTVCAxLjAvL0VO\n\t\tIiAiaHR0cDovL3d3dy5hcHBsZS5jb20vRFREcy9Qcm9wZXJ0eUxpc3QtMS4w\n\t\tLmR0ZCI+CjxwbGlzdCB2ZXJzaW9uPSIxLjAiPgo8ZGljdD4KCTxrZXk+ZmFp\n\t\tbGVkTG9naW5Db3VudDwva2V5PgoJPGludGVnZXI+MDwvaW50ZWdlcj4KCTxr\n\t\tZXk+ZmFpbGVkTG9naW5UaW1lc3RhbXA8L2tleT4KCTxkYXRlPjIwMDEtMDEt\n\t\tMDFUMDA6MDA6MDBaPC9kYXRlPgoJPGtleT5sYXN0TG9naW5UaW1lc3RhbXA8\n\t\tL2tleT4KCTxkYXRlPjIwMDEtMDEtMDFUMDA6MDA6MDBaPC9kYXRlPgoJPGtl\n\t\teT5wYXNzd29yZExhc3RTZXRUaW1lPC9rZXk+Cgk8ZGF0ZT4yMDEyLTA3LTI1\n\t\tVDE4OjQ3OjU5WjwvZGF0ZT4KPC9kaWN0Pgo8L3BsaXN0Pgo=\n\t\t</data>\n\t</array>\n\t<key>uid</key>\n\t<array>\n\t\t<string>28</string>\n\t</array>\n</dict>\n</plist>"
    end

    let(:sha512_shadowhashdata) do
      {
        'SALTED-SHA512' => 'blankvalue'
      }
    end

    let(:pbkdf2_shadowhashdata) do
      {
        'SALTED-SHA512-PBKDF2' => {
          'entropy'    => 'blank_entropy',
          'salt'       => 'blank_salt',
          'iterations' => 100
        }
      }
    end

    let(:sample_users_plist) do
      {
        "shell"                    => ["/bin/zsh"],
        "passwd"                   => ["********"],
        "picture"                  => ["/Library/User Pictures/Animals/Eagle.tif"],
        "_writers_LinkedIdentity"  => ["puppet"], "name"=>["puppet"],
        "home"                     => ["/Users/puppet"],
        "_writers_UserCertificate" => ["puppet"],
        "_writers_passwd"          => ["puppet"],
        "gid"                      => ["20"],
        "generateduid"             => ["DA8A0E67-E9BE-4B4F-B34E-8977BAE0D3D4"],
        "realname"                 => ["Puppet"],
        "_writers_picture"         => ["puppet"],
        "uid"                      => ["501"],
        "hint"                     => [""],
        "authentication_authority" => [";ShadowHash;HASHLIST:<SALTED-SHA512>",
          ";Kerberosv5;;puppet@LKDC:S HA1.35580B1D6366D2890A35D430373FF653297F377D;LKDC:SHA1.35580B1D6366D2890A35D430373FF653297F377D"],
        "_writers_realname"        => ["puppet"],
        "_writers_hint"            => ["puppet"],
        "ShadowHashData"           => ['blank']
      }
    end

    it 'should call set_salted_sha512 on 10.7 when given a salted-SHA512 password hash' do
      provider.expects(:get_users_plist).returns(sample_users_plist)
      provider.expects(:get_shadow_hash_data).with(sample_users_plist).returns(sha512_shadowhashdata)
      provider.class.expects(:get_os_version).returns('10.7')
      provider.expects(:set_salted_sha512).with(sample_users_plist, sha512_shadowhashdata, sha512_password_hash)
      provider.write_password_to_users_plist(sha512_password_hash)
    end

    it 'should call set_salted_pbkdf2 on 10.8 when given a PBKDF2 password hash' do
      provider.expects(:get_users_plist).returns(sample_users_plist)
      provider.expects(:get_shadow_hash_data).with(sample_users_plist).returns(pbkdf2_shadowhashdata)
      provider.class.expects(:get_os_version).returns('10.8')
      provider.expects(:set_salted_pbkdf2).with(sample_users_plist, pbkdf2_shadowhashdata, 'entropy', pbkdf2_password_hash)
      provider.write_password_to_users_plist(pbkdf2_password_hash)
    end

    it "should delete the SALTED-SHA512 key in the shadow_hash_data hash if it exists on a 10.8 system and write_password_to_users_plist has been called to set the user's password" do
      provider.expects(:get_users_plist).returns('users_plist')
      provider.expects(:get_shadow_hash_data).with('users_plist').returns(sha512_shadowhashdata)
      provider.class.expects(:get_os_version).returns('10.8')
      provider.expects(:set_salted_pbkdf2).with('users_plist', {}, 'entropy', pbkdf2_password_hash)
      provider.write_password_to_users_plist(pbkdf2_password_hash)
    end
  end

  describe '#set_salted_sha512' do
    let(:users_plist) { {'ShadowHashData' => ['string_data'] } }
    let(:sha512_shadow_hash_data) do
      {
        'SALTED-SHA512' => sha512_pw_string
      }
    end

    it 'should set the SALTED-SHA512 password hash for a user in 10.7 and call the set_shadow_hash_data method to write the plist to disk' do
      provider.class.expects(:convert_hash_to_binary).with(sha512_embedded_bplist_hash).returns(sha512_embedded_bplist)
      provider.expects(:set_shadow_hash_data).with(users_plist, sha512_embedded_bplist)
      provider.set_salted_sha512(users_plist, sha512_embedded_bplist_hash, sha512_password_hash)
    end

    it 'should set the salted-SHA512 password, even if a blank shadow_hash_data hash is passed' do
      provider.class.expects(:convert_hash_to_binary).with(sha512_shadow_hash_data).returns(sha512_embedded_bplist)
      provider.expects(:set_shadow_hash_data).with(users_plist, sha512_embedded_bplist)
      provider.set_salted_sha512(users_plist, false, sha512_password_hash)
    end
  end

  describe '#set_salted_pbkdf2' do
    let(:users_plist) { {'ShadowHashData' => ['string_data'] } }
    let(:entropy_shadow_hash_data) do
      {
        'SALTED-SHA512-PBKDF2' =>
        {
          'entropy' => 'binary_string'
        }
      }
    end

    # This will also catch the edge-case where a 10.6-style user exists on
    # a 10.8 system and Puppet attempts to set a password
    it 'should not fail if shadow_hash_data is not a Hash' do
      Puppet::Util::Plist.expects(:string_to_blob).with(provider.base64_decode_string(pbkdf2_password_hash)).returns('binary_string')
      provider.class.expects(:convert_hash_to_binary).with(entropy_shadow_hash_data).returns('binary_plist')
      provider.expects(:set_shadow_hash_data).with({'passwd' => '********'}, 'binary_plist')
      provider.set_salted_pbkdf2({}, false, 'entropy', pbkdf2_password_hash)
    end

    it "should set the PBKDF2 password hash when the 'entropy' field is passed with a valid password hash" do
      Puppet::Util::Plist.expects(:string_to_blob).with(provider.base64_decode_string(pbkdf2_password_hash))
      provider.class.expects(:convert_hash_to_binary).with(pbkdf2_embedded_bplist_hash).returns(pbkdf2_embedded_plist)
      provider.expects(:set_shadow_hash_data).with(users_plist, pbkdf2_embedded_plist)
      users_plist.expects(:[]=).with('passwd', '********')
      provider.set_salted_pbkdf2(users_plist, pbkdf2_embedded_bplist_hash, 'entropy', pbkdf2_password_hash)
    end

    it "should set the PBKDF2 password hash when the 'salt' field is passed with a valid password hash" do
      Puppet::Util::Plist.expects(:string_to_blob).with(provider.base64_decode_string(pbkdf2_salt_value))
      provider.class.expects(:convert_hash_to_binary).with(pbkdf2_embedded_bplist_hash).returns(pbkdf2_embedded_plist)
      provider.expects(:set_shadow_hash_data).with(users_plist, pbkdf2_embedded_plist)
      users_plist.expects(:[]=).with('passwd', '********')
      provider.set_salted_pbkdf2(users_plist, pbkdf2_embedded_bplist_hash, 'salt', pbkdf2_salt_value)
    end

    it "should set the PBKDF2 password hash when the 'iterations' field is passed with a valid password hash" do
      provider.class.expects(:convert_hash_to_binary).with(pbkdf2_embedded_bplist_hash).returns(pbkdf2_embedded_plist)
      provider.expects(:set_shadow_hash_data).with(users_plist, pbkdf2_embedded_plist)
      users_plist.expects(:[]=).with('passwd', '********')
      provider.set_salted_pbkdf2(users_plist, pbkdf2_embedded_bplist_hash, 'iterations', pbkdf2_iterations_value)
    end
  end

  describe '#write_users_plist_to_disk' do
    it 'should save the passed plist to disk and convert it to a binary plist' do
      Puppet::Util::Plist.expects(:write_plist_file).with(user_plist_xml, "#{users_plist_dir}/nonexistent_user.plist", :binary)
      provider.write_users_plist_to_disk(user_plist_xml)
    end
  end

  describe '#merge_attribute_with_dscl' do
    it 'should raise an error if a dscl command raises an error' do
      provider.expects(:dscl).with('.', '-merge', user_path, 'GeneratedUID', 'GUID').raises(Puppet::ExecutionFailure, 'boom')
      expect { provider.merge_attribute_with_dscl('Users', username, 'GeneratedUID', 'GUID') }.to raise_error Puppet::Error, /Could not set the dscl GeneratedUID key with value: GUID/
    end
  end

  describe '#get_users_plist' do
    let(:test_hash) do
      {
        'user'  => 'puppet',
        'shell' => '/bin/bash'
      }
    end

    it 'should convert a plist to a valid Ruby hash' do
      Puppet::Util::Plist.expects(:read_plist_file).with("#{users_plist_dir}/#{username}.plist").returns(test_hash)
      expect(provider.get_users_plist(username)).to eq(test_hash, )
    end
  end

  describe '#get_shadow_hash_data' do
    let(:shadow_hash) do
      {
        'ShadowHashData' => ['test']
      }
    end

    let(:no_shadow_hash) do
      {
        'no' => 'Shadow Hash Data'
      }
    end

    it 'should return false if the passed users_plist does NOT have a ShadowHashData key' do
      expect(provider.get_shadow_hash_data(no_shadow_hash)).to eq(false)
    end

    it 'should call convert_binary_to_hash() with the string ' +
       'located in the first element of the array of the ShadowHashData key if the ' +
       'passed users_plist contains a ShadowHashData key' do
      provider.class.expects(:convert_binary_to_hash).with('test').returns('returnvalue')
      expect(provider.get_shadow_hash_data(shadow_hash)).to eq('returnvalue')
    end
  end

  describe 'self#get_os_version' do
    before :each do
      # Ensure we don't have a value cached from another spec
      provider.class.instance_variable_set(:@os_version, nil) if provider.class.instance_variable_defined? :@os_version
    end

    it 'should call Facter.value(:macosx_productversion_major) ONLY ONCE no matter how ' +
       'many times get_os_version() is called' do
      Facter.expects(:value).with(:macosx_productversion_major).once.returns('10.8')
      expect(provider.class.get_os_version).to eq('10.8')
      expect(provider.class.get_os_version).to eq('10.8')
      expect(provider.class.get_os_version).to eq('10.8')
      expect(provider.class.get_os_version).to eq('10.8')
    end
  end

  describe '#base64_decode_string' do
    it 'should return a Base64-decoded string appropriate for use in a user\'s plist' do
      expect(provider.base64_decode_string(sha512_password_hash)).to eq(sha512_pw_string)
    end
  end

  describe '(#12833) 10.6-style users on 10.8' do
    # The below represents output of 'dscl -plist . readall /Users'
    # converted to a Ruby hash if only one user were installed on the system.
    # This lets us check the behavior of all the methods necessary to return
    # a user's groups property by controlling the data provided by dscl. The
    # differentiating aspect about this plist is that it's from a 10.6-style
    # user. There's an edge case whereby a user that was created in 10.6, but
    # who hasn't attempted to login to the system until after it's been
    # upgraded to 10.8, will experience errors due to assumptions in Puppet
    # based solely on operatingsystem.
    let(:all_users_hash) do
      [
        {
          "dsAttrTypeNative:_writers_UserCertificate"  => ["testuser"],
          "dsAttrTypeStandard:RealName"                => ["testuser"],
          "dsAttrTypeStandard:NFSHomeDirectory"        => ["/Users/testuser"],
          "dsAttrTypeNative:_writers_realname"         => ["testuser"],
          "dsAttrTypeNative:_writers_picture"          => ["testuser"],
          "dsAttrTypeStandard:AppleMetaNodeLocation"   => ["/Local/Default"],
          "dsAttrTypeStandard:PrimaryGroupID"          => ["20"],
          "dsAttrTypeNative:_writers_LinkedIdentity"   => ["testuser"],
          "dsAttrTypeStandard:UserShell"               => ["/bin/bash"],
          "dsAttrTypeStandard:UniqueID"                => ["1234"],
          "dsAttrTypeStandard:RecordName"              => ["testuser"],
          "dsAttrTypeStandard:Password"                => ["********"],
          "dsAttrTypeNative:_writers_jpegphoto"        => ["testuser"],
          "dsAttrTypeNative:_writers_hint"             => ["testuser"],
          "dsAttrTypeNative:_writers_passwd"           => ["testuser"],
          "dsAttrTypeStandard:RecordType"              => ["dsRecTypeStandard:Users"],
          "dsAttrTypeStandard:AuthenticationAuthority" => [
            ";ShadowHash;",
            ";Kerberosv5;;testuser@LKDC:SHA1.48AC4BCFEFE9 D66847B5E7D813BC4B12C5513A07;LKDC:SHA1.48AC4BCFEFE9D66847B5E7D813BC4B12C5513A07;"
                                                          ],
          "dsAttrTypeStandard:GeneratedUID"            => ["D1AC2ECC-F177-4B45-8B18-59CF002F97FF"]
        }
      ]
    end

    let(:username) { 'testuser' }
    let(:user_path) { "/Users/#{username}" }
    let(:resource) do
      Puppet::Type.type(:user).new(
        :name     => username,
        :provider => :directoryservice
      )
    end
    let(:provider) { resource.provider }

    # The below represents the result of get_users_plist on the testuser
    # account from the 'all_users_hash' helper method. The get_users_plist
    # method calls the `plutil` binary to do its work, so we want to stub
    # that out
    let(:user_plist_hash) do
      {
        'realname'                 => ['testuser'],
        'authentication_authority' => [';ShadowHash;', ';Kerberosv5;;testuser@LKDC:SHA1.48AC4BCFEFE9D66847B5E7D813BC4B12C5513A07;LKDC:SHA1.48AC4BCFEFE9D66847B5E7D813BC4B12C5513A07;'],
        'home'                     => ['/Users/testuser'],
        '_writers_realname'        => ['testuser'],
        'passwd'                   => '********',
        '_writers_LinkedIdentity'  => ['testuser'],
        '_writers_picture'         => ['testuser'],
        'gid'                      => ['20'],
        '_writers_passwd'          => ['testuser'],
        '_writers_hint'            => ['testuser'],
        '_writers_UserCertificate' => ['testuser'],
        '_writers_jpegphoto'       => ['testuser'],
        'shell'                    => ['/bin/bash'],
        'uid'                      => ['1234'],
        'generateduid'             => ['D1AC2ECC-F177-4B45-8B18-59CF002F97FF'],
        'name'                     => ['testuser']
      }
    end

    before :each do
      provider.class.stubs(:get_all_users).returns(all_users_hash)
      provider.class.stubs(:get_list_of_groups).returns(group_plist_hash_guid)
      provider.class.prefetch({})
    end

    it 'should not raise an error if the password=() method is called on ' +
       'a user without a ShadowHashData key in their user\'s plist on OS X ' +
       'version 10.8' do
      resource[:salt] = pbkdf2_salt_value
      resource[:iterations] = pbkdf2_iterations_value
      resource[:password] = pbkdf2_password_hash
      provider.class.stubs(:get_os_version).returns('10.8')
      provider.stubs(:sleep)
      provider.stubs(:flush_dscl_cache)

      provider.expects(:get_users_plist).with('testuser').returns(user_plist_hash)
      provider.expects(:set_salted_pbkdf2).with(user_plist_hash, false, 'entropy', pbkdf2_password_hash)
      provider.password = resource[:password]
    end
  end
end

