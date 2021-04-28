require 'spec_helper'

describe Puppet::Type.type(:package).provider(:pip2) do

  it { is_expected.to be_installable }
  it { is_expected.to be_uninstallable }
  it { is_expected.to be_upgradeable }
  it { is_expected.to be_versionable }
  it { is_expected.to be_install_options }
  it { is_expected.to be_targetable }

  it "should inherit most things from pip provider" do
    expect(described_class < Puppet::Type.type(:package).provider(:pip))
  end

  it "should use pip2 command" do
    expect(described_class.cmd).to eq(["pip2"])
  end

  context 'calculated specificity' do
    include_context 'provider specificity'

    context 'when is not defaultfor' do
      subject { described_class.specificity }
      it { is_expected.to eql 1 }
    end

    context 'when is defaultfor' do
      let(:os) { Facter.value(:operatingsystem) }
      subject do
        described_class.defaultfor(operatingsystem: os)
        described_class.specificity
      end
      it { is_expected.to be > 100 }
    end
  end

end
