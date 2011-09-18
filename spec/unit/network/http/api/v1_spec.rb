#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/network/http/api/v1'

class V1RestApiTester
  include Puppet::Network::HTTP::API::V1
end

describe Puppet::Network::HTTP::API::V1 do
  before do
    @tester = V1RestApiTester.new
  end

  it "should be able to convert a URI into a request" do
    @tester.should respond_to(:uri2indirection)
  end

  it "should be able to convert a request into a URI" do
    @tester.should respond_to(:indirection2uri)
  end

  describe "when converting a URI into a request" do
    before do
      @tester.stubs(:handler).returns "foo"
    end

    it "should require the http method, the URI, and the query parameters" do
      # Not a terribly useful test, but an important statement for the spec
      lambda { @tester.uri2indirection("/foo") }.should raise_error(ArgumentError)
    end

    it "should use the first field of the URI as the environment" do
      @tester.uri2indirection("GET", "/env/foo/bar", {})[3][:environment].to_s.should == "env"
    end

    it "should fail if the environment is not alphanumeric" do
      lambda { @tester.uri2indirection("GET", "/env ness/foo/bar", {}) }.should raise_error(ArgumentError)
    end

    it "should use the environment from the URI even if one is specified in the parameters" do
      @tester.uri2indirection("GET", "/env/foo/bar", {:environment => "otherenv"})[3][:environment].to_s.should == "env"
    end

    it "should return the environment as a Puppet::Node::Environment" do
      @tester.uri2indirection("GET", "/env/foo/bar", {})[3][:environment].should be_a Puppet::Node::Environment
    end

    it "should use the second field of the URI as the indirection name" do
      @tester.uri2indirection("GET", "/env/foo/bar", {})[0].should == "foo"
    end

    it "should fail if the indirection name is not alphanumeric" do
      lambda { @tester.uri2indirection("GET", "/env/foo ness/bar", {}) }.should raise_error(ArgumentError)
    end

    it "should use the remainder of the URI as the indirection key" do
      @tester.uri2indirection("GET", "/env/foo/bar", {})[2].should == "bar"
    end

    it "should support the indirection key being a /-separated file path" do
      @tester.uri2indirection("GET", "/env/foo/bee/baz/bomb", {})[2].should == "bee/baz/bomb"
    end

    it "should fail if no indirection key is specified" do
      lambda { @tester.uri2indirection("GET", "/env/foo/", {}) }.should raise_error(ArgumentError)
      lambda { @tester.uri2indirection("GET", "/env/foo", {}) }.should raise_error(ArgumentError)
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is singular" do
      @tester.uri2indirection("GET", "/env/foo/bar", {})[1].should == :find
    end

    it "should choose 'find' as the indirection method if the http method is a POST and the indirection name is singular" do
      @tester.uri2indirection("POST", "/env/foo/bar", {})[1].should == :find
    end

    it "should choose 'head' as the indirection method if the http method is a HEAD and the indirection name is singular" do
      @tester.uri2indirection("HEAD", "/env/foo/bar", {})[1].should == :head
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is plural" do
      @tester.uri2indirection("GET", "/env/foos/bar", {})[1].should == :search
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is facts" do
      @tester.uri2indirection("GET", "/env/facts/bar", {})[1].should == :find
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is facts" do
      @tester.uri2indirection("PUT", "/env/facts/bar", {})[1].should == :save
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is inventory" do
      @tester.uri2indirection("GET", "/env/inventory/search", {})[1].should == :search
    end

    it "should choose 'find' as the indirection method if the http method is a GET and the indirection name is facts" do
      @tester.uri2indirection("GET", "/env/facts/bar", {})[1].should == :find
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is facts" do
      @tester.uri2indirection("PUT", "/env/facts/bar", {})[1].should == :save
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is inventory" do
      @tester.uri2indirection("GET", "/env/inventory/search", {})[1].should == :search
    end

    it "should choose 'search' as the indirection method if the http method is a GET and the indirection name is facts_search" do
      @tester.uri2indirection("GET", "/env/facts_search/bar", {})[1].should == :search
    end

    it "should change indirection name to 'facts' if the http method is a GET and the indirection name is facts_search" do
      @tester.uri2indirection("GET", "/env/facts_search/bar", {})[0].should == 'facts'
    end

    it "should not change indirection name from 'facts' if the http method is a GET and the indirection name is facts" do
      @tester.uri2indirection("GET", "/env/facts/bar", {})[0].should == 'facts'
    end

    it "should change indirection name to 'status' if the http method is a GET and the indirection name is statuses" do
      @tester.uri2indirection("GET", "/env/statuses/bar", {})[0].should == 'status'
    end

    it "should change indirection name to 'probe' if the http method is a GET and the indirection name is probes" do
      @tester.uri2indirection("GET", "/env/probes/bar", {})[0].should == 'probe'
    end

    it "should choose 'delete' as the indirection method if the http method is a DELETE and the indirection name is singular" do
      @tester.uri2indirection("DELETE", "/env/foo/bar", {})[1].should == :destroy
    end

    it "should choose 'save' as the indirection method if the http method is a PUT and the indirection name is singular" do
      @tester.uri2indirection("PUT", "/env/foo/bar", {})[1].should == :save
    end

    it "should fail if an indirection method cannot be picked" do
      lambda { @tester.uri2indirection("UPDATE", "/env/foo/bar", {}) }.should raise_error(ArgumentError)
    end

    it "should URI unescape the indirection key" do
      escaped = URI.escape("foo bar")
      indirection_name, method, key, params = @tester.uri2indirection("GET", "/env/foo/#{escaped}", {})
      key.should == "foo bar"
    end
  end

  describe "when converting a request into a URI" do
    before do
      @request = Puppet::Indirector::Request.new(:foo, :find, "with spaces", :foo => :bar, :environment => "myenv")
    end

    it "should use the environment as the first field of the URI" do
      @tester.indirection2uri(@request).split("/")[1].should == "myenv"
    end

    it "should use the indirection as the second field of the URI" do
      @tester.indirection2uri(@request).split("/")[2].should == "foo"
    end

    it "should pluralize the indirection name if the method is 'search'" do
      @request.stubs(:method).returns :search
      @tester.indirection2uri(@request).split("/")[2].should == "foos"
    end

    it "should use the escaped key as the remainder of the URI" do
      escaped = URI.escape("with spaces")
      @tester.indirection2uri(@request).split("/")[3].sub(/\?.+/, '').should == escaped
    end

    it "should add the query string to the URI" do
      @request.expects(:query_string).returns "?query"
      @tester.indirection2uri(@request).should =~ /\?query$/
    end
  end

  describe "when converting a request into a URI with body" do
    before :each do
      @request = Puppet::Indirector::Request.new(:foo, :find, "with spaces", :foo => :bar, :environment => "myenv")
    end

    it "should use the environment as the first field of the URI" do
      @tester.request_to_uri_and_body(@request).first.split("/")[1].should == "myenv"
    end

    it "should use the indirection as the second field of the URI" do
      @tester.request_to_uri_and_body(@request).first.split("/")[2].should == "foo"
    end

    it "should use the escaped key as the remainder of the URI" do
      escaped = URI.escape("with spaces")
      @tester.request_to_uri_and_body(@request).first.split("/")[3].sub(/\?.+/, '').should == escaped
    end

    it "should return the URI and body separately" do
      @tester.request_to_uri_and_body(@request).should == ["/myenv/foo/with%20spaces", "foo=bar"]
    end
  end
end
