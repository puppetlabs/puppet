#! /usr/bin/env ruby
require 'spec_helper'

require 'openssl'
require 'puppet/util/ssl'

describe Puppet::Util::SSL do
  def parse(dn)
    Puppet::Util::SSL.subject_from_dn(dn)
  end

  describe "when getting a subject from a DN" do
    RSpec::Matchers.define :be_a_subject_with do |expected|
      match do |actual|
        parts = actual.to_a.map { |part| part[0..1] }.flatten
        Hash[*parts] == expected
      end
    end

    it "parses a DN with a single part" do
      parse('CN=client.example.org').should be_a_subject_with({
        'CN' => 'client.example.org'
      })
    end

    it "parses a DN with parts separated by slashes" do
      parse('/CN=Root CA/OU=Server Operations/O=Example Org').should be_a_subject_with({
        'CN' => 'Root CA',
        'OU' => 'Server Operations',
        'O'  => 'Example Org'
      })
    end

    it "parses a DN with a single part preceeded by a slash" do
      parse('/CN=client.example.org').should be_a_subject_with({
        'CN' => 'client.example.org'
      })
    end

    it "parses a DN with parts separated by commas" do
      parse('O=Foo\, Inc,CN=client2a.example.org').should be_a_subject_with({
        'O' => 'Foo, Inc',
        'CN' => 'client2a.example.org'
      })
    end
  end

  describe "when getting a CN from a subject" do
    it "should correctly parse a subject containing only a CN" do
      subj = parse('/CN=foo')
      described_class.cn_from_subject(subj).should == 'foo'
    end

    it "should correctly parse a subject containing other components" do
      subj = parse('/CN=Root CA/OU=Server Operations/O=Example Org')
      described_class.cn_from_subject(subj).should == 'Root CA'
    end

    it "should correctly parse a subject containing other components with CN not first" do
      subj = parse('/emailAddress=foo@bar.com/CN=foo.bar.com/O=Example Org')
      described_class.cn_from_subject(subj).should == 'foo.bar.com'
    end

    it "should return nil for a subject with no CN" do
      subj = parse('/OU=Server Operations/O=Example Org')
      described_class.cn_from_subject(subj).should == nil
    end

    it "should return nil for a bare string" do
      described_class.cn_from_subject("/CN=foo").should == nil
    end
  end
end

