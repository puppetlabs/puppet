# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Util::Windows do
  %w[
    ADSI
    ADSI::ADSIObject
    ADSI::User
    ADSI::UserProfile
    ADSI::Group
    EventLog
    File
    Process
    Registry
    Service
    SID
    ].each do |name|
    it "defines Puppet::Util::Windows::#{name}" do
      expect(described_class.const_get(name)).to be
    end
  end
end
