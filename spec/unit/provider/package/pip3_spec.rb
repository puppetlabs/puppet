require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pip3) do

  it { is_expected.to be_installable }
  it { is_expected.to be_uninstallable }
  it { is_expected.to be_upgradeable }
  it { is_expected.to be_versionable }
  it { is_expected.to be_install_options }
  it { is_expected.to be_targetable }

  it "should inherit most things from pip provider" do
    expect(described_class < Puppet::Type.type(:package).provider(:pip))
  end

  it "should use pip3 command" do
    expect(described_class.cmd).to eq(["pip3"])
  end

end
