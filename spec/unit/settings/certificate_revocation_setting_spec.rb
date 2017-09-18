require 'spec_helper'

require 'puppet/settings'
require 'puppet/settings/certificate_revocation_setting'

describe Puppet::Settings::CertificateRevocationSetting do
  subject { described_class.new(:settings => stub('settings'), :desc => "test") }

  it "is of type :certificate_revocation" do
    expect(subject.type).to eq :certificate_revocation
  end

  describe "munging the value" do
    ['true', true, 'chain'].each do |setting|
      it "munges #{setting.inspect} to :chain" do
        expect(subject.munge(setting)).to eq :chain
      end
    end

    it "munges 'leaf' to :leaf" do
      expect(subject.munge("leaf")).to eq :leaf
    end

    ['false', false, nil].each do |setting|
      it "munges #{setting.inspect} to false" do
        expect(subject.munge(setting)).to eq false
      end
    end

    it "raises an error when given an unexpected object type" do
        expect {
          subject.munge(1)
        }.to raise_error(Puppet::Settings::ValidationError, "Invalid certificate revocation value 1: must be one of 'true', 'chain', 'leaf', or 'false'")
    end
  end
end

