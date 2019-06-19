require 'spec_helper'
require 'puppet/network/uri'

describe Puppet::Network::Uri do
  include Puppet::Network::Uri
  describe '.mask_credentials' do
    let(:address_with_passwd) { 'https://admin:S3cr3T@puppetforge.acmecorp.com/' }
    let(:masked) { 'https://admin:***@puppetforge.acmecorp.com/' }
    let(:address) { 'https://puppetforge.acmecorp.com/' }

    subject do
      input = to_be_masked.dup
      result = mask_credentials(input)
      raise 'illegal unexpected modification' if input != to_be_masked
      result
    end

    describe 'if password was given in URI' do
      describe 'as a String' do
        let(:to_be_masked) { address_with_passwd }
        it 'should mask out password' do
          is_expected.to eq(masked)
        end
      end
      describe 'as an URI' do
        let(:to_be_masked) { URI.parse(address_with_passwd) }
        it 'should mask out password' do
          is_expected.to eq(masked)
        end
      end
    end
    describe "if password wasn't given in URI" do
      describe 'as a String' do
        let(:to_be_masked) { address }
        it "shouldn't add mask to URI" do
          is_expected.to eq(address)
        end
      end
      describe 'as an URI' do
        let(:to_be_masked) { URI.parse(address) }
        it "shouldn't add mask to URI" do
          is_expected.to eq(address)
        end
      end
    end
  end
end
