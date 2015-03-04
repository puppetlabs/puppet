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

    NO_PARTS = {}

    it "parses a DN with a single part" do
      expect(parse('CN=client.example.org')).to be_a_subject_with({
        'CN' => 'client.example.org'
      })
    end

    it "parses a DN with parts separated by slashes" do
      expect(parse('/CN=Root CA/OU=Server Operations/O=Example Org')).to be_a_subject_with({
        'CN' => 'Root CA',
        'OU' => 'Server Operations',
        'O'  => 'Example Org'
      })
    end

    it "parses a DN with a single part preceded by a slash" do
      expect(parse('/CN=client.example.org')).to be_a_subject_with({
        'CN' => 'client.example.org'
      })
    end

    it "parses a DN with parts separated by commas" do
      expect(parse('O=Foo\, Inc,CN=client2a.example.org')).to be_a_subject_with({
        'O' => 'Foo, Inc',
        'CN' => 'client2a.example.org'
      })
    end

    it "finds no parts in something that is not a DN" do
      expect(parse('(no)')).to be_a_subject_with(NO_PARTS)
    end

    it "finds no parts in a DN with an invalid part" do
      expect(parse('no=yes,CN=Root CA')).to be_a_subject_with(NO_PARTS)
    end

    it "finds no parts in an empty DN" do
      expect(parse('')).to be_a_subject_with(NO_PARTS)
    end
  end

  describe "when getting a CN from a subject" do
    def cn_from(subject)
      Puppet::Util::SSL.cn_from_subject(subject)
    end

    it "should correctly parse a subject containing only a CN" do
      subj = parse('/CN=foo')
      expect(cn_from(subj)).to eq('foo')
    end

    it "should correctly parse a subject containing other components" do
      subj = parse('/CN=Root CA/OU=Server Operations/O=Example Org')
      expect(cn_from(subj)).to eq('Root CA')
    end

    it "should correctly parse a subject containing other components with CN not first" do
      subj = parse('/emailAddress=foo@bar.com/CN=foo.bar.com/O=Example Org')
      expect(cn_from(subj)).to eq('foo.bar.com')
    end

    it "should return nil for a subject with no CN" do
      subj = parse('/OU=Server Operations/O=Example Org')
      expect(cn_from(subj)).to eq(nil)
    end

    it "should return nil for a bare string" do
      expect(cn_from("/CN=foo")).to eq(nil)
    end
  end
end

