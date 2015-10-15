require 'spec_helper'

describe Puppet::Type.type(:group).provider(:directoryservice) do
  let :resource do
    Puppet::Type.type(:group).new(
      :title => 'testgroup',
      :provider => :directoryservice,
    )
  end

  let(:provider) { resource.provider }

  it 'should return true for same lists of unordered members' do
    expect(provider.members_insync?(['user1', 'user2'], ['user2', 'user1'])).to be_truthy
  end

  it 'should return false when the group currently has no members' do
    expect(provider.members_insync?([], ['user2', 'user1'])).to be_falsey
  end

  it 'should return true for the same lists of members irrespective of duplicates' do
    expect(provider.members_insync?(['user1', 'user2', 'user2'], ['user1', 'user2'])).to be_truthy
  end

  it "should return true when current and should members are empty lists" do
    expect(provider.members_insync?([], [])).to be_truthy
  end

  it "should return true when current is :absent and should members is empty list" do
    expect(provider.members_insync?(:absent, [])).to be_truthy
  end

end
