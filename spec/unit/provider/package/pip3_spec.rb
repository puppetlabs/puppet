require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pip3) do

  it "should inherit most things from pip provider" do
    expect(described_class < Puppet::Type.type(:package).provider(:pip))
  end

  it "should use pip3 command" do
    expect(described_class.cmd).to eq(["pip3"])
  end

end
