require 'puppet'
require 'spec_helper'
require 'puppet_spec/character_encoding'

# The Ruby::Etc module is largely non-functional on Windows - many methods
# simply return nil regardless of input, the Etc::Group struct is not defined,
# and Etc::Passwd is missing fields
# We want to test that:
# - We correctly set external encoding values IF they're valid UTF-8 bytes
# - We do not modify non-UTF-8 values if they're NOT valid UTF-8 bytes

describe Puppet::Etc, :if => !Puppet.features.microsoft_windows? do
  # http://www.fileformat.info/info/unicode/char/5e0c/index.htm
  # 希 Han Character 'rare; hope, expect, strive for'
  # In EUC_KR: \xfd \xf1 - 253 241
  # In UTF-8: \u5e0c - \xe5 \xb8 \x8c - 229 184 140
  let(:euc_kr) { [253, 241].pack('C*').force_encoding(Encoding::EUC_KR) } # valid_encoding? == true
  let(:euc_kr_as_binary) { [253, 241].pack('C*') } # valid_encoding? == true
  let(:euc_kr_as_utf_8) { [253, 241].pack('C*').force_encoding(Encoding::UTF_8) } # valid_encoding? == false

  # characters representing different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  let(:mixed_utf_8) { "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::UTF_8) } # Aۿᚠ𠜎
  let(:mixed_utf_8_as_binary) { "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::BINARY) }
  let(:mixed_utf_8_as_euc_kr) { "A\u06FF\u16A0\u{2070E}".force_encoding(Encoding::EUC_KR) }

  # An uninteresting value that ruby might return in an Etc struct.
  let(:root) { 'root' }

  # Set up example Etc Group structs with values representative of what we would
  # get back in these encodings

  let(:utf_8_group_struct) do
    group = Etc::Group.new
    # In a UTF-8 environment, these values will come back as UTF-8, even if
    # they're not valid UTF-8. We do not modify anything about either the
    # valid or invalid UTF-8 strings.

    # Group member contains a mix of valid and invalid UTF-8-labeled strings
    group.mem = [mixed_utf_8, root.dup.force_encoding(Encoding::UTF_8), euc_kr_as_utf_8]
    # group name contains same EUC_KR bytes labeled as UTF-8
    group.name = euc_kr_as_utf_8
    # group passwd field is valid UTF-8
    group.passwd = mixed_utf_8
    group.gid = 12345
    group
  end

  let(:euc_kr_group_struct) do
    # In an EUC_KR environment, values will come back as EUC_KR, even if they're
    # not valid in that encoding. For values that are valid in UTF-8 we expect
    # their external encoding to be set to UTF-8 by Puppet::Etc. For values that
    # are invalid in UTF-8, we expect the string to be kept intact, unmodified,
    # as we can't transcode it.
    group = Etc::Group.new
    group.mem = [euc_kr, root.dup.force_encoding(Encoding::EUC_KR), mixed_utf_8_as_euc_kr]
    group.name = euc_kr
    group.passwd = mixed_utf_8_as_euc_kr
    group.gid = 12345
    group
  end

  let(:ascii_group_struct) do
    # In a POSIX environment, any strings containing only values under
    # code-point 128 will be returned as ASCII, whereas anything above that
    # point will be returned as BINARY. In either case we override the encoding
    # to UTF-8 if that would be valid.
    group = Etc::Group.new
    group.mem = [euc_kr_as_binary, root.dup.force_encoding(Encoding::ASCII), mixed_utf_8_as_binary]
    group.name = euc_kr_as_binary
    group.passwd = mixed_utf_8_as_binary
    group.gid = 12345
    group
  end

  let(:utf_8_user_struct) do
    user = Etc::Passwd.new
    # user name contains same EUC_KR bytes labeled as UTF-8
    user.name = euc_kr_as_utf_8
    # group passwd field is valid UTF-8
    user.passwd = mixed_utf_8
    user.uid = 12345
    user
  end

  let(:euc_kr_user_struct) do
    user = Etc::Passwd.new
    user.name = euc_kr
    user.passwd = mixed_utf_8_as_euc_kr
    user.uid = 12345
    user
  end

  let(:ascii_user_struct) do
    user = Etc::Passwd.new
    user.name = euc_kr_as_binary
    user.passwd = mixed_utf_8_as_binary
    user.uid = 12345
    user
  end

  shared_examples "methods that return an overridden group struct from Etc" do |params|

    it "should return a new Struct object with corresponding canonical_ members" do
      group = Etc::Group.new
      Etc.expects(subject).with(*params).returns(group)
      puppet_group = Puppet::Etc.send(subject, *params)

      expect(puppet_group.members).to include(*group.members)
      expect(puppet_group.members).to include(*group.members.map { |mem| "canonical_#{mem}".to_sym })

      # Confirm we haven't just added the new members to the original struct object, ie this is really a new struct
      expect(group.members.any? { |elem| elem.match(/^canonical_/) }).to be_falsey
    end

    context "when Encoding.default_external is UTF-8" do
      before do
        Etc.expects(subject).with(*params).returns(utf_8_group_struct)
      end

      let(:overridden) {
        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::UTF_8) do
          Puppet::Etc.send(subject, *params)
        end
      }

      it "should leave the valid UTF-8 values in arrays unmodified" do
        expect(overridden.mem[0]).to eq(mixed_utf_8)
        expect(overridden.mem[1]).to eq(root)
      end

      it "should replace invalid characters with replacement characters in invalid UTF-8 values in arrays" do
        expect(overridden.mem[2]).to eq("\uFFFD\uFFFD")
      end

      it "should keep an unmodified version of the invalid UTF-8 values in arrays in the corresponding canonical_ member" do
        expect(overridden.canonical_mem[2]).to eq(euc_kr_as_utf_8)
      end

      it "should leave the valid UTF-8 values unmodified" do
        expect(overridden.passwd).to eq(mixed_utf_8)
      end

      it "should replace invalid characters with '?' characters in invalid UTF-8 values" do
        expect(overridden.name).to eq("\uFFFD\uFFFD")
      end

      it "should keep an unmodified version of the invalid UTF-8 values in the corresponding canonical_ member" do
        expect(overridden.canonical_name).to eq(euc_kr_as_utf_8)
      end

      it "should copy all values to the new struct object" do
        # Confirm we've actually copied all the values to the canonical_members
        utf_8_group_struct.each_pair do |member, value|
          expect(overridden["canonical_#{member}"]).to eq(value)

          # Confirm we've reassigned all non-string and array values
          if !value.is_a?(String) && !value.is_a?(Array)
            expect(overridden[member]).to eq(value)
            expect(overridden[member].object_id).to eq(value.object_id)
          end
        end
      end
    end

    context "when Encoding.default_external is EUC_KR (i.e., neither UTF-8 nor POSIX)" do
      before do
        Etc.expects(subject).with(*params).returns(euc_kr_group_struct)
      end

      let(:overridden) {
        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::EUC_KR) do
          Puppet::Etc.send(subject, *params)
        end
      }

      it "should override EUC_KR-labeled values in arrays to UTF-8 if that would result in valid UTF-8" do
        expect(overridden.mem[2]).to eq(mixed_utf_8)
        expect(overridden.mem[1]).to eq(root)
      end

      it "should leave valid EUC_KR-labeled values that would not be valid UTF-8 in arrays unmodified" do
        expect(overridden.mem[0]).to eq(euc_kr)
      end

      it "should override EUC_KR-labeled values to UTF-8 if that would result in valid UTF-8" do
        expect(overridden.passwd).to eq(mixed_utf_8)
      end

      it "should leave valid EUC_KR-labeled values that would not be valid UTF-8 unmodified" do
        expect(overridden.name).to eq(euc_kr)
      end

      it "should copy all values to the new struct object" do
        # Confirm we've actually copied all the values to the canonical_members
        euc_kr_group_struct.each_pair do |member, value|
          expect(overridden["canonical_#{member}"]).to eq(value)

          # Confirm we've reassigned all non-string and array values
          if !value.is_a?(String) && !value.is_a?(Array)
            expect(overridden[member]).to eq(value)
            expect(overridden[member].object_id).to eq(value.object_id)
          end
        end
      end
    end

    context "when Encoding.default_external is POSIX (ASCII-7bit)" do
      before do
        Etc.expects(subject).with(*params).returns(ascii_group_struct)
      end

      let(:overridden) {
        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ASCII) do
          Puppet::Etc.send(subject, *params)
        end
      }

      it "should not modify binary values in arrays that would be invalid UTF-8" do
        expect(overridden.mem[0]).to eq(euc_kr_as_binary)
      end

      it "should set the encoding to UTF-8 on binary values in arrays that would be valid UTF-8" do
        expect(overridden.mem[1]).to eq(root.dup.force_encoding(Encoding::UTF_8))
        expect(overridden.mem[2]).to eq(mixed_utf_8)
      end

      it "should not modify binary values that would be invalid UTF-8" do
        expect(overridden.name).to eq(euc_kr_as_binary)
      end

      it "should set the encoding to UTF-8 on binary values that would be valid UTF-8" do
        expect(overridden.passwd).to eq(mixed_utf_8)
      end

      it "should copy all values to the new struct object" do
        # Confirm we've actually copied all the values to the canonical_members
        ascii_group_struct.each_pair do |member, value|
          expect(overridden["canonical_#{member}"]).to eq(value)

          # Confirm we've reassigned all non-string and array values
          if !value.is_a?(String) && !value.is_a?(Array)
            expect(overridden[member]).to eq(value)
            expect(overridden[member].object_id).to eq(value.object_id)
          end
        end
      end
    end
  end

  shared_examples "methods that return an overridden user struct from Etc" do |params|

    it "should return a new Struct object with corresponding canonical_ members" do
      user = Etc::Passwd.new
      Etc.expects(subject).with(*params).returns(user)
      puppet_user = Puppet::Etc.send(subject, *params)

      expect(puppet_user.members).to include(*user.members)
      expect(puppet_user.members).to include(*user.members.map { |mem| "canonical_#{mem}".to_sym })
      # Confirm we haven't just added the new members to the original struct object, ie this is really a new struct
      expect(user.members.any? { |elem| elem.match(/^canonical_/)}).to be_falsey
    end

    context "when Encoding.default_external is UTF-8" do
      before do
        Etc.expects(subject).with(*params).returns(utf_8_user_struct)
      end

      let(:overridden) {
        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::UTF_8) do
          Puppet::Etc.send(subject, *params)
        end
      }

      it "should leave the valid UTF-8 values unmodified" do
        expect(overridden.passwd).to eq(mixed_utf_8)
      end

      it "should replace invalid characters with unicode replacement characters in invalid UTF-8 values" do
        expect(overridden.name).to eq("\uFFFD\uFFFD")
      end

      it "should keep an unmodified version of the invalid UTF-8 values in the corresponding canonical_ member" do
        expect(overridden.canonical_name).to eq(euc_kr_as_utf_8)
      end

      it "should copy all values to the new struct object" do
        # Confirm we've actually copied all the values to the canonical_members
        utf_8_user_struct.each_pair do |member, value|
          expect(overridden["canonical_#{member}"]).to eq(value)

          # Confirm we've reassigned all non-string and array values
          if !value.is_a?(String) && !value.is_a?(Array)
            expect(overridden[member]).to eq(value)
            expect(overridden[member].object_id).to eq(value.object_id)
          end
        end
      end
    end

    context "when Encoding.default_external is EUC_KR (i.e., neither UTF-8 nor POSIX)" do
      before do
        Etc.expects(subject).with(*params).returns(euc_kr_user_struct)
      end

      let(:overridden) {
        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::EUC_KR) do
          Puppet::Etc.send(subject, *params)
        end
      }

      it "should override valid UTF-8 EUC_KR-labeled values to UTF-8" do
        expect(overridden.passwd).to eq(mixed_utf_8)
      end

      it "should leave invalid EUC_KR-labeled values unmodified" do
        expect(overridden.name).to eq(euc_kr)
      end

      it "should copy all values to the new struct object" do
        # Confirm we've actually copied all the values to the canonical_members
        euc_kr_user_struct.each_pair do |member, value|
          expect(overridden["canonical_#{member}"]).to eq(value)

          # Confirm we've reassigned all non-string and array values
          if !value.is_a?(String) && !value.is_a?(Array)
            expect(overridden[member]).to eq(value)
            expect(overridden[member].object_id).to eq(value.object_id)
          end
        end
      end
    end

    context "when Encoding.default_external is POSIX (ASCII-7bit)" do
      before do
        Etc.expects(subject).with(*params).returns(ascii_user_struct)
      end

      let(:overridden) {
        PuppetSpec::CharacterEncoding.with_external_encoding(Encoding::ASCII) do
          Puppet::Etc.send(subject, *params)
        end
      }

      it "should not modify binary values that would be invalid UTF-8" do
        expect(overridden.name).to eq(euc_kr_as_binary)
      end

      it "should set the encoding to UTF-8 on binary values that would be valid UTF-8" do
        expect(overridden.passwd).to eq(mixed_utf_8)
      end

      it "should copy all values to the new struct object" do
        # Confirm we've actually copied all the values to the canonical_members
        ascii_user_struct.each_pair do |member, value|
          expect(overridden["canonical_#{member}"]).to eq(value)

          # Confirm we've reassigned all non-string and array values
          if !value.is_a?(String) && !value.is_a?(Array)
            expect(overridden[member]).to eq(value)
            expect(overridden[member].object_id).to eq(value.object_id)
          end
        end
      end
    end
  end

  describe :getgrent do
    it_should_behave_like "methods that return an overridden group struct from Etc"
  end

  describe :getgrnam do
    it_should_behave_like "methods that return an overridden group struct from Etc", 'foo'

    it "should call Etc.getgrnam with the supplied group name" do
      Etc.expects(:getgrnam).with('foo')
      Puppet::Etc.getgrnam('foo')
    end
  end

  describe :getgrgid do
    it_should_behave_like "methods that return an overridden group struct from Etc", 0

    it "should call Etc.getgrgid with supplied group id" do
      Etc.expects(:getgrgid).with(0)
      Puppet::Etc.getgrgid(0)
    end
  end

  describe :getpwent do
    it_should_behave_like "methods that return an overridden user struct from Etc"
  end

  describe :getpwnam do
    it_should_behave_like "methods that return an overridden user struct from Etc", 'foo'

    it "should call Etc.getpwnam with that username" do
      Etc.expects(:getpwnam).with('foo')
      Puppet::Etc.getpwnam('foo')
    end
  end

  describe :getpwuid do
    it_should_behave_like "methods that return an overridden user struct from Etc", 2

    it "should call Etc.getpwuid with the id" do
      Etc.expects(:getpwuid).with(2)
      Puppet::Etc.getpwuid(2)
    end
  end

  describe "endgrent" do
    it "should call Etc.getgrent" do
      Etc.expects(:getgrent)
      Puppet::Etc.getgrent
    end
  end

  describe "setgrent" do
    it "should call Etc.setgrent" do
      Etc.expects(:setgrent)
      Puppet::Etc.setgrent
    end
  end

  describe "endpwent" do
    it "should call Etc.endpwent" do
      Etc.expects(:endpwent)
      Puppet::Etc.endpwent
    end
  end

  describe "setpwent" do
    it "should call Etc.setpwent" do
      Etc.expects(:setpwent)
      Puppet::Etc.setpwent
    end
  end
end
