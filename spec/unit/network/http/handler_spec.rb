#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector_testing'

require 'puppet/network/http'
require 'puppet/network/http/handler'
require 'puppet/network/authorization'
require 'puppet/network/authentication'

describe Puppet::Network::HTTP::Handler do
  before :each do
    Puppet::IndirectorTesting.indirection.terminus_class = :memory
  end

  let(:indirection) { Puppet::IndirectorTesting.indirection }

  def a_request
    {
      :accept_header => "pson",
      :content_type_header => "text/yaml",
      :http_method => "HEAD",
      :path => "/production/#{indirection.name}/unknown",
      :params => {},
      :client_cert => nil,
      :headers => {},
      :body => nil
    }
  end

  let(:handler) { TestingHandler.new }

  describe "when processing a request" do
    let(:response) do
      { :status => 200 }
    end

    before do
      handler.stubs(:check_authorization)
      handler.stubs(:warn_if_near_expiration)
    end

    it "should check the client certificate for upcoming expiration" do
      request = a_request
      cert = mock 'cert'
      handler.expects(:client_cert).returns(cert).with(request)
      handler.expects(:warn_if_near_expiration).with(cert)

      handler.process(request, response)
    end

    it "should setup a profiler when the puppet-profiling header exists" do
      request = a_request
      request[:headers][Puppet::Network::HTTP::HEADER_ENABLE_PROFILING.downcase] = "true"

      handler.process(request, response)

      Puppet::Util::Profiler.current.should be_kind_of(Puppet::Util::Profiler::WallClock)
    end

    it "should not setup profiler when the profile parameter is missing" do
      request = a_request
      request[:params] = { }

      handler.process(request, response)

      Puppet::Util::Profiler.current.should == Puppet::Util::Profiler::NONE
    end

    it "should raise an error if the request is formatted in an unknown format" do
      handler.stubs(:content_type_header).returns "unknown format"
      lambda { handler.request_format(request) }.should raise_error
    end

    it "should still find the correct format if content type contains charset information" do
      request = Puppet::Network::HTTP::Handler::Request.new({ 'content-type' => "text/plain; charset=UTF-8" },
                                                            {}, 'GET', '/', nil)
      request.format.should == "s"
    end

    it "should deserialize YAML parameters" do
      params = {'my_param' => [1,2,3].to_yaml}

      decoded_params = handler.send(:decode_params, params)

      decoded_params.should == {:my_param => [1,2,3]}
    end

    it "should ignore tags on YAML parameters" do
      params = {'my_param' => "--- !ruby/object:Array {}"}

      decoded_params = handler.send(:decode_params, params)

      decoded_params[:my_param].should be_a(Hash)
    end
  end


  describe "when resolving node" do
    it "should use a look-up from the ip address" do
      Resolv.expects(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4")
    end

    it "should return the look-up result" do
      Resolv.stubs(:getname).with("1.2.3.4").returns("host.domain.com")

      handler.resolve_node(:ip => "1.2.3.4").should == "host.domain.com"
    end

    it "should return the ip address if resolving fails" do
      Resolv.stubs(:getname).with("1.2.3.4").raises(RuntimeError, "no such host")

      handler.resolve_node(:ip => "1.2.3.4").should == "1.2.3.4"
    end
  end

  class TestingHandler
    include Puppet::Network::HTTP::Handler

    def accept_header(request)
      request[:accept_header]
    end

    def content_type_header(request)
      request[:content_type_header]
    end

    def set_content_type(response, format)
      "my_result"
    end

    def set_response(response, body, status = 200)
      response[:body] = body
      response[:status] = status
    end

    def http_method(request)
      request[:http_method]
    end

    def path(request)
      request[:path]
    end

    def params(request)
      request[:params]
    end

    def client_cert(request)
      request[:client_cert]
    end

    def body(request)
      request[:body]
    end

    def headers(request)
      request[:headers] || {}
    end
  end
end
