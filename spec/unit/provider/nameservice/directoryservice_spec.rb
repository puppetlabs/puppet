require 'spec_helper'

module Puppet::Util::Plist
end

# We use this as a reasonable way to obtain all the support infrastructure.
[:group].each do |type_for_this_round|
  describe Puppet::Type.type(type_for_this_round).provider(:directoryservice) do
    before do
      @resource = double("resource")
      allow(@resource).to receive(:[]).with(:name)
      @provider = described_class.new(@resource)
    end

    it "[#6009] should handle nested arrays of members" do
      current = ["foo", "bar", "baz"]
      desired = ["foo", ["quux"], "qorp"]
      group   = 'example'

      allow(@resource).to receive(:[]).with(:name).and_return(group)
      allow(@resource).to receive(:[]).with(:auth_membership).and_return(true)
      @provider.instance_variable_set(:@property_value_cache_hash,
                                      { :members => current })

      %w{bar baz}.each do |del|
        expect(@provider).to receive(:execute).once.
          with([:dseditgroup, '-o', 'edit', '-n', '.', '-d', del, group])
      end

      %w{quux qorp}.each do |add|
        expect(@provider).to receive(:execute).once.
          with([:dseditgroup, '-o', 'edit', '-n', '.', '-a', add, group])
      end

      expect { @provider.set(:members, desired) }.to_not raise_error
    end
  end
end

describe Puppet::Provider::NameService::DirectoryService do
  context '.single_report' do
    it 'should use plist data' do
      allow(Puppet::Provider::NameService::DirectoryService).to receive(:get_ds_path).and_return('Users')
      allow(Puppet::Provider::NameService::DirectoryService).to receive(:list_all_present).and_return(
        ['root', 'user1', 'user2', 'resource_name']
      )
      allow(Puppet::Provider::NameService::DirectoryService).to receive(:generate_attribute_hash)
      allow(Puppet::Provider::NameService::DirectoryService).to receive(:execute)
      expect(Puppet::Provider::NameService::DirectoryService).to receive(:parse_dscl_plist_data)

      Puppet::Provider::NameService::DirectoryService.single_report('resource_name')
    end
  end

  context '.get_exec_preamble' do
    it 'should use plist data' do
      allow(Puppet::Provider::NameService::DirectoryService).to receive(:get_ds_path).and_return('Users')

      expect(Puppet::Provider::NameService::DirectoryService.get_exec_preamble('-list')).to include("-plist")
    end
  end

  context 'password behavior' do
    # The below is a binary plist containing a ShadowHashData key which CONTAINS
    # another binary plist. The nested binary plist contains a 'SALTED-SHA512'
    # key that contains a base64 encoded salted-SHA512 password hash...
    let (:binary_plist) { "bplist00\324\001\002\003\004\005\006\a\bXCRAM-MD5RNT]SALTED-SHA512[RECOVERABLEO\020 \231k2\3360\200GI\201\355J\216\202\215y\243\001\206J\300\363\032\031\022\006\2359\024\257\217<\361O\020\020F\353\at\377\277\226\276c\306\254\031\037J(\235O\020D\335\006{\3744g@\377z\204\322\r\332t\021\330\n\003\246K\223\356\034!P\261\305t\035\346\352p\206\003n\247MMA\310\301Z<\366\246\023\0161W3\340\357\000\317T\t\301\311+\204\246L7\276\370\320*\245O\021\002\000k\024\221\270x\353\001\237\346D}\377?\265]\356+\243\v[\350\316a\340h\376<\322\266\327\016\306n\272r\t\212A\253L\216\214\205\016\241 [\360/\335\002#\\A\372\241a\261\346\346\\\251\330\312\365\016\n\341\017\016\225&;\322\\\004*\ru\316\372\a \362?8\031\247\231\030\030\267\315\023\v\343{@\227\301s\372h\212\000a\244&\231\366\nt\277\2036,\027bZ+\223W\212g\333`\264\331N\306\307\362\257(^~ b\262\247&\231\261t\341\231%\244\247\203eOt\365\271\201\273\330\350\363C^A\327F\214!\217hgf\e\320k\260n\315u~\336\371M\t\235k\230S\375\311\303\240\351\037d\273\321y\335=K\016`_\317\230\2612_\023K\036\350\v\232\323Y\310\317_\035\227%\237\v\340\023\016\243\233\025\306:\227\351\370\364x\234\231\266\367\016w\275\333-\351\210}\375x\034\262\272kRuHa\362T/F!\347B\231O`K\304\037'k$$\245h)e\363\365mT\b\317\\2\361\026\351\254\375Jl1~\r\371\267\352\2322I\341\272\376\243^Un\266E7\230[VocUJ\220N\2116D/\025f=\213\314\325\vG}\311\360\377DT\307m\261&\263\340\272\243_\020\271rG^BW\210\030l\344\0324\335\233\300\023\272\225Im\330\n\227*Yv[\006\315\330y'\a\321\373\273A\240\305F{S\246I#/\355\2425\031\031GGF\270y\n\331\004\023G@\331\000\361\343\350\264$\032\355_\210y\000\205\342\375\212q\024\004\026W:\205 \363v?\035\270L-\270=\022\323\2003\v\336\277\t\237\356\374\n\267n\003\367\342\330;\371S\326\016`B6@Njm>\240\021%\336\345\002(P\204Yn\3279l\0228\264\254\304\2528t\372h\217\347sA\314\345\245\337)]\000\b\000\021\000\032\000\035\000+\0007\000Z\000m\000\264\000\000\000\000\000\000\002\001\000\000\000\000\000\000\000\t\000\000\000\000\000\000\000\000\000\000\000\000\000\000\002\270" }

    # The below is a base64 encoded salted-SHA512 password hash.
    let (:pw_string) { "\335\006{\3744g@\377z\204\322\r\332t\021\330\n\003\246K\223\356\034!P\261\305t\035\346\352p\206\003n\247MMA\310\301Z<\366\246\023\0161W3\340\357\000\317T\t\301\311+\204\246L7\276\370\320*\245" }

    # The below is a salted-SHA512 password hash in hex.
    let (:sha512_hash) { 'dd067bfc346740ff7a84d20dda7411d80a03a64b93ee1c2150b1c5741de6ea7086036ea74d4d41c8c15a3cf6a6130e315733e0ef00cf5409c1c92b84a64c37bef8d02aa5' }

    let :plist_path do
      '/var/db/dslocal/nodes/Default/users/jeff.plist'
    end

    let :ds_provider do
      described_class
    end

    let :shadow_hash_data do
      {'ShadowHashData' => [binary_plist]}
    end

    it 'should execute convert_binary_to_hash once when getting the password' do
      expect(described_class).to receive(:convert_binary_to_hash).and_return({'SALTED-SHA512' => pw_string})
      expect(Puppet::FileSystem).to receive(:exist?).with(plist_path).once.and_return(true)
      expect(Puppet::Util::Plist).to receive(:read_plist_file).and_return(shadow_hash_data)
      described_class.get_password('uid', 'jeff')
    end

    it 'should fail if a salted-SHA512 password hash is not passed in' do
      expect {
        described_class.set_password('jeff', 'uid', 'badpassword')
      }.to raise_error(RuntimeError, /OS X 10.7 requires a Salted SHA512 hash password of 136 characters./)
    end

    it 'should convert xml-to-binary and binary-to-xml when setting the pw on >= 10.7' do
      expect(described_class).to receive(:convert_binary_to_hash).and_return({'SALTED-SHA512' => pw_string})
      expect(described_class).to receive(:convert_hash_to_binary).and_return(binary_plist)
      expect(Puppet::FileSystem).to receive(:exist?).with(plist_path).once.and_return(true)
      expect(Puppet::Util::Plist).to receive(:read_plist_file).and_return(shadow_hash_data)
      expect(Puppet::Util::Plist).to receive(:write_plist_file).with(shadow_hash_data, plist_path, :binary)
      described_class.set_password('jeff', 'uid', sha512_hash)
    end

    it '[#13686] should handle an empty ShadowHashData field in the users plist' do
      expect(described_class).to receive(:convert_hash_to_binary).and_return(binary_plist)
      expect(Puppet::FileSystem).to receive(:exist?).with(plist_path).once.and_return(true)
      expect(Puppet::Util::Plist).to receive(:read_plist_file).and_return({'ShadowHashData' => nil})
      expect(Puppet::Util::Plist).to receive(:write_plist_file)
      described_class.set_password('jeff', 'uid', sha512_hash)
    end
  end

  context '(#4855) directoryservice group resource failure' do
    let :provider_class do
      Puppet::Type.type(:group).provider(:directoryservice)
    end

    let :group_members do
      ['root','jeff']
    end

    let :user_account do
      ['root']
    end

    let :stub_resource do
      double('resource')
    end

    subject do
      provider_class.new(stub_resource)
    end

    before :each do
      @resource = double("resource")
      allow(@resource).to receive(:[]).with(:name)
      @provider = provider_class.new(@resource)
    end

    it 'should delete a group member if the user does not exist' do
      allow(stub_resource).to receive(:[]).with(:name).and_return('fake_group')
      allow(stub_resource).to receive(:name).and_return('fake_group')
      expect(subject).to receive(:execute).with([:dseditgroup, '-o', 'edit', '-n', '.',
                                                '-d', 'jeff',
                                                'fake_group']).and_raise(Puppet::ExecutionFailure, 'it broke')
      expect(subject).to receive(:execute).with([:dscl, '.', '-delete',
                                                '/Groups/fake_group', 'GroupMembership',
                                                'jeff'])
      subject.remove_unwanted_members(group_members, user_account)
    end
  end
end
