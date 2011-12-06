require 'spec_helper'
require 'net/http'
require 'puppet/module_tool'

describe Puppet::Module::Tool::Repository do
  describe 'instances' do
    before do
      @repository = described_class.new('http://fake.com')
    end

    describe '#make_http_request' do
      before do
        # Do a mock of the Proxy call so we can do proper expects for
        # Net::HTTP
        Net::HTTP.expects(:Proxy).returns(Net::HTTP)
        Net::HTTP.expects(:start)
      end
      context "when not given an :authenticate option" do
        it "should authenticate" do
          @repository.expects(:authenticate).never
          @repository.make_http_request(nil)
        end
      end
      context "when given an :authenticate option" do
        it "should authenticate" do
          @repository.expects(:authenticate)
          @repository.make_http_request(nil, :authenticate => true)
        end
      end
    end

    describe '#authenticate' do
      it "should set basic auth on the request" do
        authenticated_request = stub
        authenticated_request.expects(:basic_auth)
        @repository.expects(:prompt).twice
        @repository.authenticate(authenticated_request)
      end
    end

    describe '#retrieve' do
      before do
        @uri = URI.parse('http://some.url.com')
      end

      it "should access the cache" do
        @repository.cache.expects(:retrieve).with(@uri)
        @repository.retrieve(@uri)
      end
    end
  end
end
