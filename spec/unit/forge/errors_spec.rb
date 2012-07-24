require 'spec_helper'
require 'puppet/forge/errors'

describe Puppet::Forge::Errors do
  describe 'SSLVerifyError' do
    subject { Puppet::Forge::Errors::SSLVerifyError }
    let(:exception) { subject.new(:uri => 'https://fake.com:1111') }

    it 'should return a valid single line error' do
      exception.message.should == 'Unable to verify the SSL certificate at https://fake.com:1111'
    end

    it 'should return a valid multiline error' do
      exception.multiline.should == <<-EOS.chomp
Could not connect via HTTPS to https://fake.com:1111
  Unable to verify the SSL certificate
    The certificate may not be signed by a valid CA
    The CA bundle included with OpenSSL may not be valid or up to date
      EOS
    end
  end

  describe 'CommunicationError' do
    subject { Puppet::Forge::Errors::CommunicationError }
    let(:socket_exception) { SocketError.new('There was a problem') }
    let(:exception) { subject.new(:uri => 'http://fake.com:1111', :original => socket_exception) }

    it 'should return a valid single line error' do
      exception.message.should == 'Unable to connect to the server at http://fake.com:1111. Detail: There was a problem.'
    end

    it 'should return a valid multiline error' do
      exception.multiline.should == <<-EOS.chomp
Could not connect to http://fake.com:1111
  There was a network communications problem
    The error we caught said 'There was a problem'
    Check your network connection and try again
      EOS
    end
  end

end
