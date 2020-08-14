require 'spec_helper'

describe Dir, :if => Puppet::Util::Platform.windows? do
  it "should always have the PERSONAL constant defined" do
    expect(described_class).to be_const_defined(:PERSONAL)
  end

  it "should not raise any errors when accessing the PERSONAL constant" do
    expect { described_class::PERSONAL }.not_to raise_error
  end
end
