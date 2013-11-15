require 'spec_helper'

require 'puppet/ssl/certificate_authority/autosign_command'

describe Puppet::SSL::CertificateAuthority::AutosignCommand do

  subject { described_class.new('/autosign/command') }

  before :each do
    Puppet::SSL::CertificateRequest.indirection.stubs(:find).returns(stub 'csr', :to_s => 'CSR PEM goes here')
  end

  it "returns true if the command succeeded" do
    executes_the_command_resulting_in(0)

    subject.allowed?('host').should == true
  end

  it "returns false if the command failed" do
    executes_the_command_resulting_in(1)

    subject.allowed?('host').should == false
  end

  def executes_the_command_resulting_in(exitstatus)
    Puppet::Util::Execution.expects(:execute).
      with('/autosign/command host',
           has_entries(:stdinfile => anything,
                       :combine => true,
                       :failonfail => false)).
      returns(Puppet::Util::Execution::ProcessOutput.new('', exitstatus))
  end
end
