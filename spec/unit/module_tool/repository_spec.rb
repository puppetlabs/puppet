require 'spec_helper'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Module::Tool::Repository do
  describe 'instances' do
    before do
      @repository = described_class.new('http://fake.com')
    end

    describe '#contact' do
      before do
        # Do a mock of the Proxy call so we can do proper expects for
        # Net::HTTP
        Net::HTTP.expects(:Proxy).returns(Net::HTTP)
        Net::HTTP.expects(:start)
      end
      context "when not given an :authenticate option" do
        it "should authenticate" do
          @repository.expects(:authenticate).never
          @repository.contact(nil)
        end
      end
      context "when given an :authenticate option" do
        it "should authenticate" do
          @repository.expects(:authenticate)
          @repository.contact(nil, :authenticate => true)
        end
      end
    end

    describe '#authenticate' do
      before do
        @request = stub
        @repository.expects(:prompt).twice
      end

      it "should set basic auth on the request" do
        @request.expects(:basic_auth)
        @repository.authenticate(@request)
      end
    end

    describe '#retrieve' do
      before do
        @uri = URI.parse('http://some.url.com')
        @repository.cache.expects(:retrieve).with(@uri)
      end
      it "should access the cache" do
        @repository.retrieve(@uri)
      end
    end
  end
end
