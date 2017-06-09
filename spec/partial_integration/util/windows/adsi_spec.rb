#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe Puppet::Util::Windows::ADSI::User,
  :if => Puppet.features.microsoft_windows? do

  describe ".initialize" do
    it "cannot reference BUILTIN accounts like SYSTEM due to WinNT moniker limitations" do
      system = Puppet::Util::Windows::ADSI::User.new('SYSTEM')
      # trying to retrieve COM object should fail to load with a localized version of:
      # ADSI connection error: failed to parse display name of moniker `WinNT://./SYSTEM,user'
      #     HRESULT error code:0x800708ad
      #           The user name could not be found.
      # Matching on error code alone is sufficient
      expect { system.native_user }.to raise_error(/0x800708ad/)
    end
  end

  describe '.each' do
    it 'should return a list of users with UTF-8 names' do
      begin
        original_codepage = Encoding.default_external
        Encoding.default_external = Encoding::CP850 # Western Europe

        Puppet::Util::Windows::ADSI::User.each do |user|
          expect(user.name.encoding).to be(Encoding::UTF_8)
        end
      ensure
        Encoding.default_external = original_codepage
      end
    end
  end

  describe '.[]' do
    it 'should return string attributes as UTF-8' do
      administrator = Puppet::Util::Windows::ADSI::User.new('Administrator')
      expect(administrator['Description'].encoding).to eq(Encoding::UTF_8)
    end
  end

  describe '.groups' do
    it 'should return a list of groups with UTF-8 names' do
      begin
        original_codepage = Encoding.default_external
        Encoding.default_external = Encoding::CP850 # Western Europe


        # lookup by English name Administrator is OK on localized Windows
        administrator = Puppet::Util::Windows::ADSI::User.new('Administrator')
        administrator.groups.each do |name|
          expect(name.encoding).to be(Encoding::UTF_8)
        end
      ensure
        Encoding.default_external = original_codepage
      end
    end
  end
end

describe Puppet::Util::Windows::ADSI::Group,
  :if => Puppet.features.microsoft_windows? do

  let (:administrator_bytes) { [1, 2, 0, 0, 0, 0, 0, 5, 32, 0, 0, 0, 32, 2, 0, 0] }
  let (:administrators_principal) { Puppet::Util::Windows::SID::Principal.lookup_account_sid(administrator_bytes) }

  describe '.each' do
    it 'should return a list of groups with UTF-8 names' do
      begin
        original_codepage = Encoding.default_external
        Encoding.default_external = Encoding::CP850 # Western Europe


        Puppet::Util::Windows::ADSI::Group.each do |group|
          expect(group.name.encoding).to be(Encoding::UTF_8)
        end
      ensure
        Encoding.default_external = original_codepage
      end
    end
  end

  describe '.members' do
    it 'should return a list of members with UTF-8 names' do
      begin
        original_codepage = Encoding.default_external
        Encoding.default_external = Encoding::CP850 # Western Europe

        # lookup by English name Administrators is not OK on localized Windows
        admins = Puppet::Util::Windows::ADSI::Group.new(administrators_principal.account)
        admins.members.each do |name|
          expect(name.encoding).to be(Encoding::UTF_8)
        end
      ensure
        Encoding.default_external = original_codepage
      end
    end
  end
end
