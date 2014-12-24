#!/usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe "Puppet::Util::Windows::AccessControlList", :if => Puppet.features.microsoft_windows? do
  let(:klass) { Puppet::Util::Windows::AccessControlList }
  let(:system_sid) { 'S-1-5-18' }
  let(:admins_sid) { 'S-1-5-544' }
  let(:none_sid)   { 'S-1-0-0' }

  let(:system_ace) do
    Puppet::Util::Windows::AccessControlEntry.new(system_sid, 0x1)
  end
  let(:admins_ace) do
    Puppet::Util::Windows::AccessControlEntry.new(admins_sid, 0x2)
  end
  let(:none_ace) do
    Puppet::Util::Windows::AccessControlEntry.new(none_sid, 0x3)
  end

  it "constructs an empty list" do
    acl = klass.new

    expect(acl.to_a).to be_empty
  end

  it "supports copy constructor" do
    aces = klass.new([system_ace]).to_a

    expect(aces.to_a).to eq([system_ace])
  end

  context "appending" do
    it "appends an allow ace" do
      acl = klass.new
      acl.allow(system_sid, 0x1, 0x2)

      expect(acl.first.type).to eq(klass::ACCESS_ALLOWED_ACE_TYPE)
    end

    it "appends a deny ace" do
      acl = klass.new
      acl.deny(system_sid, 0x1, 0x2)

      expect(acl.first.type).to eq(klass::ACCESS_DENIED_ACE_TYPE)
    end

    it "always appends, never overwrites an ACE" do
      acl = klass.new([system_ace])
      acl.allow(admins_sid, admins_ace.mask, admins_ace.flags)

      aces = acl.to_a
      expect(aces.size).to eq(2)
      expect(aces[0]).to eq(system_ace)
      expect(aces[1].sid).to eq(admins_sid)
      expect(aces[1].mask).to eq(admins_ace.mask)
      expect(aces[1].flags).to eq(admins_ace.flags)
    end
  end

  context "reassigning" do
    it "preserves the mask from the old sid when reassigning to the new sid" do
      dacl = klass.new([system_ace])

      dacl.reassign!(system_ace.sid, admins_ace.sid)
      # we removed system, so ignore prepended ace
      ace = dacl.to_a[1]
      expect(ace.sid).to eq(admins_sid)
      expect(ace.mask).to eq(system_ace.mask)
    end

    it "matches multiple sids" do
      dacl = klass.new([system_ace, system_ace])

      dacl.reassign!(system_ace.sid, admins_ace.sid)
      # we removed system, so ignore prepended ace
      aces = dacl.to_a
      expect(aces.size).to eq(3)
      aces.to_a[1,2].each do |ace|
        expect(ace.sid).to eq(admins_ace.sid)
      end
    end

    it "preserves aces for sids that don't match, in their original order" do
      dacl = klass.new([system_ace, admins_ace])

      dacl.reassign!(system_sid, none_sid)
      aces = dacl.to_a
      aces[1].sid == admins_ace.sid
    end

    it "preserves inherited aces, even if the sids match" do
      flags = Puppet::Util::Windows::AccessControlEntry::INHERITED_ACE
      inherited_ace = Puppet::Util::Windows::AccessControlEntry.new(system_sid, 0x1, flags)
      dacl = klass.new([inherited_ace, system_ace])
      dacl.reassign!(system_sid, none_sid)
      aces = dacl.to_a

      expect(aces[0].sid).to eq(system_sid)
    end

    it "prepends an explicit ace for the new sid with the same mask and basic inheritance as the inherited ace" do
      expected_flags =
        Puppet::Util::Windows::AccessControlEntry::OBJECT_INHERIT_ACE |
        Puppet::Util::Windows::AccessControlEntry::CONTAINER_INHERIT_ACE |
        Puppet::Util::Windows::AccessControlEntry::INHERIT_ONLY_ACE

      flags = Puppet::Util::Windows::AccessControlEntry::INHERITED_ACE | expected_flags

      inherited_ace = Puppet::Util::Windows::AccessControlEntry.new(system_sid, 0x1, flags)
      dacl = klass.new([inherited_ace])
      dacl.reassign!(system_sid, none_sid)
      aces = dacl.to_a

      expect(aces.size).to eq(2)
      expect(aces[0].sid).to eq(none_sid)
      expect(aces[0]).not_to be_inherited
      expect(aces[0].flags).to eq(expected_flags)

      expect(aces[1].sid).to eq(system_sid)
      expect(aces[1]).to be_inherited
    end

    it "makes a copy of the ace prior to modifying it" do
      arr = [system_ace]

      acl = klass.new(arr)
      acl.reassign!(system_sid, none_sid)

      expect(arr[0].sid).to eq(system_sid)
    end
  end
end
