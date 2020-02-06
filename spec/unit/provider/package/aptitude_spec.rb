require 'spec_helper'

describe Puppet::Type.type(:package).provider(:aptitude) do
  let :type do Puppet::Type.type(:package) end
  let :pkg do
    type.new(:name => 'faff', :provider => :aptitude, :source => '/tmp/faff.deb')
  end

  it { is_expected.to be_versionable }

  context "when retrieving ensure" do
    let(:dpkgquery_path) { '/bin/dpkg-query' }

    before do
      allow(Puppet::Util).to receive(:which).with('/usr/bin/dpkg-query').and_return(dpkgquery_path)
    end

    { :absent   => "deinstall ok config-files faff 1.2.3-1\n",
      "1.2.3-1" => "install ok installed faff 1.2.3-1\n",
    }.each do |expect, output|
      it "detects #{expect} packages" do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          [dpkgquery_path, '-W', '--showformat', "'${Status} ${Package} ${Version}\\n'", 'faff'],
          {:failonfail => true, :combine => true, :custom_environment => {}}
        ).and_return(Puppet::Util::Execution::ProcessOutput.new(output, 0))

        expect(pkg.property(:ensure).retrieve).to eq(expect)
      end
    end
  end

  it "installs when asked" do
    expect(pkg.provider).to receive(:aptitude).
      with('-y', '-o', 'DPkg::Options::=--force-confold', :install, 'faff').
      and_return(0)
    expect(pkg.provider).to receive(:properties).and_return({:mark => :none})

    pkg.provider.install
  end

  it "purges when asked" do
    expect(pkg.provider).to receive(:aptitude).with('-y', 'purge', 'faff').and_return(0)
    pkg.provider.purge
  end
end
