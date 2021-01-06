require 'spec_helper'

require 'puppet/ffi/posix'
require 'puppet/util/posix'

class PosixTest
  include Puppet::Util::POSIX
end

describe Puppet::Util::POSIX do
  before do
    @posix = PosixTest.new
  end

  describe '.groups_of' do 
    let(:mock_user_data) { double(user, :gid => 1000) }

    let(:ngroups_ptr) { double('FFI::MemoryPointer', :address => 0x0001, :size => 4) }
    let(:groups_ptr) { double('FFI::MemoryPointer', :address => 0x0002, :size => Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS) }

    let(:mock_groups) do
      [
        ['root', ['root'], 0],
        ['nomembers', [], 5 ],
        ['group1', ['user1', 'user2'], 1001],
        ['group2', ['user2'], 2002],
        ['group1', ['user1', 'user2'], 1001],
        ['group3', ['user1'], 3003],
        ['group4', ['user2'], 4004],
        ['user1', [], 1111],
        ['user2', [], 2222]
      ].map do |(name, members, gid)|
        group_struct = double("Group #{name}")
        allow(group_struct).to receive(:name).and_return(name)
        allow(group_struct).to receive(:mem).and_return(members)
        allow(group_struct).to receive(:gid).and_return(gid)

        group_struct
      end
    end

    def prepare_user_and_groups_env(user, groups)
      groups_gids = []
      groups_and_user = []
      groups_and_user.replace(groups)
      groups_and_user.push(user)

      groups_and_user.each do |group|
        mock_group = mock_groups.find { |m| m.name == group }
        groups_gids.push(mock_group.gid)

        allow(Puppet::Etc).to receive(:getgrgid).with(mock_group.gid).and_return(mock_group)
      end

      if groups_and_user.size > Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS
        allow(ngroups_ptr).to receive(:read_int).and_return(Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS, groups_and_user.size)
      else
        allow(ngroups_ptr).to receive(:read_int).and_return(groups_and_user.size)
      end

      allow(groups_ptr).to receive(:get_array_of_uint).with(0, groups_and_user.size).and_return(groups_gids)
      allow(Puppet::Etc).to receive(:getpwnam).with(user).and_return(mock_user_data)
    end

    before(:each) do
      allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
    end

    describe 'when it uses FFI function getgrouplist' do
      before(:each) do
        allow(FFI::MemoryPointer).to receive(:new).with(:int).and_yield(ngroups_ptr)
        allow(FFI::MemoryPointer).to receive(:new).with(:uint, Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS).and_yield(groups_ptr)
        allow(ngroups_ptr).to receive(:write_int).with(Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS).and_return(ngroups_ptr)
      end

      describe 'when there are groups' do
        context 'for user1' do
          let(:user) { 'user1' }
          let(:expected_groups) { ['group1', 'group3'] }

          before(:each) do
            prepare_user_and_groups_env(user, expected_groups)
            allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(1)
          end

          it "should return the groups for given user" do
            expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
          end

          it 'should not print any debug message about falling back to Puppet::Etc.group' do
            expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
            Puppet::Util::POSIX.groups_of(user)
          end
        end

        context 'for user2' do
          let(:user) { 'user2' }
          let(:expected_groups) { ['group1', 'group2', 'group4'] }

          before(:each) do
            prepare_user_and_groups_env(user, expected_groups)
            allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
            allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(1)
          end

          it "should return the groups for given user" do
            expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
          end

          it 'should not print any debug message about falling back to Puppet::Etc.group' do
            expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
            Puppet::Util::POSIX.groups_of(user)
          end
        end
      end

      describe 'when there are no groups' do
        let(:user) { 'nomembers' }
        let(:expected_groups) { [] }

        before(:each) do
          prepare_user_and_groups_env(user, expected_groups)
          allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
          allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(1)
        end

        it "should return no groups for given user" do
          expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
        end

        it 'should not print any debug message about falling back to Puppet::Etc.group' do
          expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
          Puppet::Util::POSIX.groups_of(user)
        end
      end

      describe 'when primary group explicitly contains user' do
        let(:user) { 'root' }
        let(:expected_groups) { ['root'] }

        before(:each) do
          prepare_user_and_groups_env(user, expected_groups)
          allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
          allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(1)
        end

        it "should return the groups, including primary group, for given user" do
          expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
        end

        it 'should not print any debug message about falling back to Puppet::Etc.group' do
          expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
          Puppet::Util::POSIX.groups_of(user)
        end
      end

      describe 'when primary group does not explicitly contain user' do
        let(:user) { 'user1' }
        let(:expected_groups) { ['group1', 'group3'] }

        before(:each) do
          prepare_user_and_groups_env(user, expected_groups)
          allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
          allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(1)
        end

        it "should not return primary group for given user" do
          expect(Puppet::Util::POSIX.groups_of(user)).not_to include(user)
        end

        it 'should not print any debug message about falling back to Puppet::Etc.group' do
          expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
          Puppet::Util::POSIX.groups_of(user)
        end
      end

      context 'number of groups' do
        before(:each) do
          stub_const("Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS", 2)
          prepare_user_and_groups_env(user, expected_groups)

          allow(FFI::MemoryPointer).to receive(:new).with(:uint, Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS).and_yield(groups_ptr)
          allow(ngroups_ptr).to receive(:write_int).with(Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS).and_return(ngroups_ptr)
        end

        describe 'when there are less than maximum expected number of groups' do
          let(:user) { 'root' }
          let(:expected_groups) { ['root'] }

          before(:each) do
            allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
            allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(1)
          end

          it "should return the groups for given user, after one 'getgrouplist' call" do
            expect(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).once
            expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
          end

          it 'should not print any debug message about falling back to Puppet::Etc.group' do
            expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
            Puppet::Util::POSIX.groups_of(user)
          end
        end

        describe 'when there are more than maximum expected number of groups' do
          let(:user) { 'user1' }
          let(:expected_groups) { ['group1', 'group3'] }

          before(:each) do
            allow(FFI::MemoryPointer).to receive(:new).with(:uint, Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS * 2).and_yield(groups_ptr)
            allow(ngroups_ptr).to receive(:write_int).with(Puppet::FFI::POSIX::Constants::MAXIMUM_NUMBER_OF_GROUPS * 2).and_return(ngroups_ptr)

            allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(true)
            allow(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).and_return(-1, 1)
          end

          it "should return the groups for given user, after two 'getgrouplist' calls" do
            expect(Puppet::FFI::POSIX::Functions).to receive(:getgrouplist).twice
            expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
          end

          it 'should not print any debug message about falling back to Puppet::Etc.group' do
            expect(Puppet).not_to receive(:debug).with(/Falling back to Puppet::Etc.group:/)
            Puppet::Util::POSIX.groups_of(user)
          end
        end
      end
    end

    describe 'when it falls back to Puppet::Etc.group method' do
      before(:each) do
        etc_stub = receive(:group)
        mock_groups.each do |mock_group|
          etc_stub = etc_stub.and_yield(mock_group)
        end
        allow(Puppet::Etc).to etc_stub

        allow(Puppet::Etc).to receive(:getpwnam).with(user).and_raise(ArgumentError, "can't find user for #{user}")
        allow(Puppet).to receive(:debug)

        allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist, any_args).and_return(false)
      end

      describe 'when there are groups' do
        context 'for user1' do
          let(:user) { 'user1' }
          let(:expected_groups) { ['group1', 'group3'] }

          it "should return the groups for given user" do
            expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
          end

          it 'logs a debug message' do
            expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: The 'getgrouplist' method is not available")
            Puppet::Util::POSIX.groups_of(user)
          end
        end

        context 'for user2' do
          let(:user) { 'user2' }
          let(:expected_groups) { ['group1', 'group2', 'group4'] }

          it "should return the groups for given user" do
            expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
          end

          it 'logs a debug message' do
            expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: The 'getgrouplist' method is not available")
            Puppet::Util::POSIX.groups_of(user)
          end
        end
      end

      describe 'when there are no groups' do
        let(:user) { 'nomembers' }
        let(:expected_groups) { [] }

        it "should return no groups for given user" do
          expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
        end

        it 'logs a debug message' do
          expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: The 'getgrouplist' method is not available")
          Puppet::Util::POSIX.groups_of(user)
        end
      end

      describe 'when primary group explicitly contains user' do
        let(:user) { 'root' }
        let(:expected_groups) { ['root'] }

        it "should return the groups, including primary group, for given user" do
          expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
        end

        it 'logs a debug message' do
          expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: The 'getgrouplist' method is not available")
          Puppet::Util::POSIX.groups_of(user)
        end
      end

      describe 'when primary group does not explicitly contain user' do
        let(:user) { 'user1' }
        let(:expected_groups) { ['group1', 'group3'] }

        it "should not return primary group for given user" do
          expect(Puppet::Util::POSIX.groups_of(user)).not_to include(user)
        end

        it 'logs a debug message' do
          expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: The 'getgrouplist' method is not available")
          Puppet::Util::POSIX.groups_of(user)
        end
      end

      describe "when the 'getgrouplist' method is not available" do
        let(:user) { 'user1' }
        let(:expected_groups) { ['group1', 'group3'] }

        before(:each) do
          allow(Puppet::FFI::POSIX::Functions).to receive(:respond_to?).with(:getgrouplist).and_return(false)
        end

        it "should return the groups" do
          expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
        end

        it 'logs a debug message' do
          expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: The 'getgrouplist' method is not available")
          Puppet::Util::POSIX.groups_of(user)
        end
      end


      describe "when ffi is not available on the machine" do
        let(:user) { 'user1' }
        let(:expected_groups) { ['group1', 'group3'] }

        before(:each) do
          allow(Puppet::Util::POSIX).to receive(:require).with('puppet/ffi/posix').and_raise(LoadError, 'cannot load such file -- ffi')
        end

        it "should return the groups" do
          expect(Puppet::Util::POSIX.groups_of(user)).to eql(expected_groups)
        end

        it 'logs a debug message' do
          expect(Puppet).to receive(:debug).with("Falling back to Puppet::Etc.group: cannot load such file -- ffi")
          Puppet::Util::POSIX.groups_of(user)
        end
      end
    end
  end

  [:group, :gr].each do |name|
    it "should return :gid as the field for #{name}" do
      expect(@posix.idfield(name)).to eq(:gid)
    end

    it "should return :getgrgid as the id method for #{name}" do
      expect(@posix.methodbyid(name)).to eq(:getgrgid)
    end

    it "should return :getgrnam as the name method for #{name}" do
      expect(@posix.methodbyname(name)).to eq(:getgrnam)
    end
  end

  [:user, :pw, :passwd].each do |name|
    it "should return :uid as the field for #{name}" do
      expect(@posix.idfield(name)).to eq(:uid)
    end

    it "should return :getpwuid as the id method for #{name}" do
      expect(@posix.methodbyid(name)).to eq(:getpwuid)
    end

    it "should return :getpwnam as the name method for #{name}" do
      expect(@posix.methodbyname(name)).to eq(:getpwnam)
    end
  end

  describe "when retrieving a posix field" do
    before do
      @thing = double('thing', :field => "asdf")
    end

    it "should fail if no id was passed" do
      expect { @posix.get_posix_field("asdf", "bar", nil) }.to raise_error(Puppet::DevError)
    end

    describe "and the id is an integer" do
      it "should log an error and return nil if the specified id is greater than the maximum allowed ID" do
        Puppet[:maximum_uid] = 100
        expect(Puppet).to receive(:err)

        expect(@posix.get_posix_field("asdf", "bar", 200)).to be_nil
      end

      it "should use the method return by :methodbyid and return the specified field" do
        expect(Etc).to receive(:getgrgid).and_return(@thing)

        expect(@thing).to receive(:field).and_return("myval")

        expect(@posix.get_posix_field(:gr, :field, 200)).to eq("myval")
      end

      it "should return nil if the method throws an exception" do
        expect(Etc).to receive(:getgrgid).and_raise(ArgumentError)

        expect(@thing).not_to receive(:field)

        expect(@posix.get_posix_field(:gr, :field, 200)).to be_nil
      end
    end

    describe "and the id is not an integer" do
      it "should use the method return by :methodbyid and return the specified field" do
        expect(Etc).to receive(:getgrnam).and_return(@thing)

        expect(@thing).to receive(:field).and_return("myval")

        expect(@posix.get_posix_field(:gr, :field, "asdf")).to eq("myval")
      end

      it "should return nil if the method throws an exception" do
        expect(Etc).to receive(:getgrnam).and_raise(ArgumentError)

        expect(@thing).not_to receive(:field)

        expect(@posix.get_posix_field(:gr, :field, "asdf")).to be_nil
      end
    end
  end

  describe "when returning the gid" do
    before do
      allow(@posix).to receive(:get_posix_field)
    end

    describe "and the group is an integer" do
      it "should convert integers specified as a string into an integer" do
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100)

        @posix.gid("100")
      end

      it "should look up the name for the group" do
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100)

        @posix.gid(100)
      end

      it "should return nil if the group cannot be found" do
        expect(@posix).to receive(:get_posix_field).once.and_return(nil)
        expect(@posix).not_to receive(:search_posix_field)

        expect(@posix.gid(100)).to be_nil
      end

      it "should use the found name to look up the id" do
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100).and_return("asdf")
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf").and_return(100)

        expect(@posix.gid(100)).to eq(100)
      end

      # LAK: This is because some platforms have a broken Etc module that always return
      # the same group.
      it "should use :search_posix_field if the discovered id does not match the passed-in id" do
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100).and_return("asdf")
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf").and_return(50)

        expect(@posix).to receive(:search_posix_field).with(:group, :gid, 100).and_return("asdf")

        expect(@posix.gid(100)).to eq("asdf")
      end
    end

    describe "and the group is a string" do
      it "should look up the gid for the group" do
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf")

        @posix.gid("asdf")
      end

      it "should return nil if the group cannot be found" do
        expect(@posix).to receive(:get_posix_field).once.and_return(nil)
        expect(@posix).not_to receive(:search_posix_field)

        expect(@posix.gid("asdf")).to be_nil
      end

      it "should use the found gid to look up the nam" do
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100).and_return("asdf")

        expect(@posix.gid("asdf")).to eq(100)
      end

      it "returns the id without full groups query if multiple groups have the same id" do
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100).and_return("boo")
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "boo").and_return(100)

        expect(@posix).not_to receive(:search_posix_field)
        expect(@posix.gid("asdf")).to eq(100)
      end

      it "returns the id with full groups query if name is nil" do
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100).and_return(nil)
        expect(@posix).not_to receive(:get_posix_field).with(:group, :gid, nil)


        expect(@posix).to receive(:search_posix_field).with(:group, :gid, "asdf").and_return(100)
        expect(@posix.gid("asdf")).to eq(100)
      end

      it "should use :search_posix_field if the discovered name does not match the passed-in name" do
        expect(@posix).to receive(:get_posix_field).with(:group, :gid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:group, :name, 100).and_return("boo")

        expect(@posix).to receive(:search_posix_field).with(:group, :gid, "asdf").and_return("asdf")

        expect(@posix.gid("asdf")).to eq("asdf")
      end
    end
  end

  describe "when returning the uid" do
    before do
      allow(@posix).to receive(:get_posix_field)
    end

    describe "and the group is an integer" do
      it "should convert integers specified as a string into an integer" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100)

        @posix.uid("100")
      end

      it "should look up the name for the group" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100)

        @posix.uid(100)
      end

      it "should return nil if the group cannot be found" do
        expect(@posix).to receive(:get_posix_field).once.and_return(nil)
        expect(@posix).not_to receive(:search_posix_field)

        expect(@posix.uid(100)).to be_nil
      end

      it "should use the found name to look up the id" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100).and_return("asdf")
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf").and_return(100)

        expect(@posix.uid(100)).to eq(100)
      end

      # LAK: This is because some platforms have a broken Etc module that always return
      # the same group.
      it "should use :search_posix_field if the discovered id does not match the passed-in id" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100).and_return("asdf")
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf").and_return(50)

        expect(@posix).to receive(:search_posix_field).with(:passwd, :uid, 100).and_return("asdf")

        expect(@posix.uid(100)).to eq("asdf")
      end
    end

    describe "and the group is a string" do
      it "should look up the uid for the group" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf")

        @posix.uid("asdf")
      end

      it "should return nil if the group cannot be found" do
        expect(@posix).to receive(:get_posix_field).once.and_return(nil)
        expect(@posix).not_to receive(:search_posix_field)

        expect(@posix.uid("asdf")).to be_nil
      end

      it "should use the found uid to look up the nam" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100).and_return("asdf")

        expect(@posix.uid("asdf")).to eq(100)
      end

      it "returns the id without full users query if multiple users have the same id" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100).and_return("boo")
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "boo").and_return(100)

        expect(@posix).not_to receive(:search_posix_field)
        expect(@posix.uid("asdf")).to eq(100)
      end

      it "returns the id with full users query if name is nil" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100).and_return(nil)
        expect(@posix).not_to receive(:get_posix_field).with(:passwd, :uid, nil)


        expect(@posix).to receive(:search_posix_field).with(:passwd, :uid, "asdf").and_return(100)
        expect(@posix.uid("asdf")).to eq(100)
      end

      it "should use :search_posix_field if the discovered name does not match the passed-in name" do
        expect(@posix).to receive(:get_posix_field).with(:passwd, :uid, "asdf").and_return(100)
        expect(@posix).to receive(:get_posix_field).with(:passwd, :name, 100).and_return("boo")

        expect(@posix).to receive(:search_posix_field).with(:passwd, :uid, "asdf").and_return("asdf")

        expect(@posix.uid("asdf")).to eq("asdf")
      end
    end
  end

  it "should be able to iteratively search for posix values" do
    expect(@posix).to respond_to(:search_posix_field)
  end
end
