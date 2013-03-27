#! /usr/bin/env ruby
require 'spec_helper'

require 'openssl'
require 'puppet/util/ssl'

describe Puppet::Util::SSL do
  describe "when getting a subject from a DN" do
    [['/CN=Root CA/OU=Server Operations/O=Example Org',
            [['CN', 'Root CA'], ['OU', 'Server Operations'], ['O', 'Example Org']]],
     ['/CN=client.example.org',
            [['CN', 'client.example.org']]],
     ['CN=client.example.org',
            [['CN', 'client.example.org']]],
     ['O=Foo\, Inc,CN=client2a.example.org',
            [['CN', 'client2a.example.org'], ['O', 'Foo, Inc']]],
    ].each do |dn, exp|
      it "parses #{dn} correctly to #{exp.inspect}" do
        # parse out the important bits of the Name object to compare
        described_class.subject_from_dn(dn).to_a.map { |a| [a[0], a[1]] }.should === exp
      end
    end
  end

  describe "when getting a CN from a subject" do
    it "should correctly parse a subject containing only a CN" do
      subj = OpenSSL::X509::Name.parse('/CN=foo')
      described_class.cn_from_subject(subj).should == 'foo'
    end

    it "should correctly parse a subject containing other components" do
      subj = OpenSSL::X509::Name.parse('/CN=Root CA/OU=Server Operations/O=Example Org')
      described_class.cn_from_subject(subj).should == 'Root CA'
    end

    it "should correctly parse a subject containing other components with CN not first" do
      subj = OpenSSL::X509::Name.parse('/emailAddress=foo@bar.com/CN=foo.bar.com/O=Example Org')
      described_class.cn_from_subject(subj).should == 'foo.bar.com'
    end

    it "should return nil for a subject with no CN" do
      subj = OpenSSL::X509::Name.parse('/OU=Server Operations/O=Example Org')
      described_class.cn_from_subject(subj).should == nil
    end

    it "should return nil for a bare string" do
      described_class.cn_from_subject("/CN=foo").should == nil
    end
  end
end

