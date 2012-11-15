#! /usr/bin/env ruby
#

require 'puppet/ssl/configuration'

describe Puppet::SSL::Configuration do
  let(:localcacert) { "/path/to/certs/ca.pem" }

  let(:ssl_server_ca_chain) { "/path/to/certs/ssl_server_ca_chain.pem" }
  let(:ssl_server_ca_auth) { "/path/to/certs/ssl_server_ca_auth.pem" }

  it "should require the localcacert argument" do
    lambda { subject }.should raise_error ArgumentError
  end

  context "Default configuration" do
    subject do
      described_class.new(localcacert)
    end
    it "#ca_chain_file == localcacert" do
      subject.ca_chain_file.should == localcacert
    end
    it "#ca_auth_file == localcacert" do
      subject.ca_auth_file.should == localcacert
    end
  end

  context "Explicitly configured" do
    subject do
      options = {
        :ca_chain_file => ssl_server_ca_chain,
        :ca_auth_file  => ssl_server_ca_auth,
      }
      Puppet::SSL::Configuration.new(localcacert, options)
    end

    it "#ca_chain_file == ssl_server_ca_chain" do
      subject.ca_chain_file.should == ssl_server_ca_chain
    end
    it "#ca_auth_file == ssl_server_ca_auth" do
      subject.ca_auth_file.should == ssl_server_ca_auth
    end
  end

  context "Partially configured" do
    it "should error if only ca_chain_file is specified" do
      lambda {
        described_class.new(localcacert, { :ca_chain_file => "/path/to/cert.pem" })
      }.should raise_error ArgumentError
    end
    describe "#ca_chain_file" do
      subject do
        described_class.new(localcacert, { :ca_auth_file => ssl_server_ca_auth })
      end
      it "should use ca_auth_file" do
        subject.ca_chain_file.should == ssl_server_ca_auth
      end
    end
  end
end
