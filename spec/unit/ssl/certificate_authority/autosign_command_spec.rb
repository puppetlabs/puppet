require 'spec_helper'

require 'puppet/ssl/certificate_authority/autosign_command'

describe Puppet::SSL::CertificateAuthority::AutosignCommand do

  subject { described_class.new('/autosign/command') }

  before :each do
    Puppet::Util::Execution.stubs(:execute).with('/autosign/command host', anything).returns('')
    Puppet::SSL::CertificateRequest.indirection.stubs(:find).returns(stub 'csr', :to_s => 'CSR PEM goes here')
  end


  it "runs the command with the CSR certname and body" do
    tmpfile = stub('tempfile', :path => '/path/to/csr/tempfile', :write => nil)
    Tempfile.stubs(:new).returns tmpfile

    Puppet::Util::Execution.expects(:execute).with do |cmd, args|
      cmd.should eq '/autosign/command host'
      args.should include(:stdinfile => '/path/to/csr/tempfile')
    end.returns ''
    $CHILD_STATUS.stubs(:exitstatus).returns 0

    subject.allowed?('host')
  end

  it "returns true if the command succeeded" do
    $CHILD_STATUS.stubs(:exitstatus).returns 0
    subject.allowed?('host').should == true
  end

  it "returns false if the command failed" do
    $CHILD_STATUS.stubs(:exitstatus).returns 1
    subject.allowed?('host').should == false
  end

  it "raises an error if the command failed with a non-1 exit status" do
    $CHILD_STATUS.stubs(:exitstatus).returns 255
    subject.allowed?('host').should == false
  end
end
