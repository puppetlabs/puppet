require 'spec_helper'

require 'puppet/ssl/certificate_authority/autosign_command'

describe Puppet::SSL::CertificateAuthority::AutosignCommand do
  let(:csr) { double('csr', :name => 'host', :to_s => 'CSR PEM goes here') }
  let(:decider) { Puppet::SSL::CertificateAuthority::AutosignCommand.new('/autosign/command') }

  it "returns true if the command succeeded" do
    executes_the_command_resulting_in(0)

    expect(decider.allowed?(csr)).to eq(true)
  end

  it "returns false if the command failed" do
    executes_the_command_resulting_in(1)

    expect(decider.allowed?(csr)).to eq(false)
  end

  def executes_the_command_resulting_in(exitstatus)
    expect(Puppet::Util::Execution).to receive(:execute).
      with(['/autosign/command', 'host'],
           hash_including(:stdinfile => anything,
                          :combine => true,
                          :failonfail => false)).
      and_return(Puppet::Util::Execution::ProcessOutput.new('', exitstatus))
  end
end
