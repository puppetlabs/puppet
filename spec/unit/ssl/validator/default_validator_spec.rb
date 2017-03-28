require 'spec_helper'
require 'puppet/ssl'

describe Puppet::SSL::Validator::DefaultValidator do
  context "#initialize" do
    it "logs a deprecation warning that the class is deprecated" do
      Puppet.expects(:deprecation_warning).with(regexp_matches(/.*/))
      described_class.new
    end
  end

  context "#setup_connection" do
    let(:no_validator) { mock('Puppet::SSL::Validator::NoValidator') }
    let(:unauthenticated_validator) { mock('Puppet::SSL::Validator::UnauthenticatedValidator') }

    before do
      no_validator.expects(:setup_connection).once
      unauthenticated_validator.expects(:setup_connection).once
    end

    it "generates a new validator upon each invocation" do
      Puppet::SSL::Validator.expects(:best_validator).twice.returns(no_validator, unauthenticated_validator)

      subject.setup_connection(nil)
      expect(subject.validator).to eq(no_validator)
      subject.setup_connection(nil)
      expect(subject.validator).to eq(unauthenticated_validator)
    end
  end
end
