#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/reports'

processor = Puppet::Reports.report(:http)

describe processor do
  subject { Puppet::Transaction::Report.new("apply").extend(processor) }

  describe "when setting up the connection" do
    let(:http) { stub_everything "http" }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }

    before :each do
      http.expects(:post).returns(httpok)
    end

    it "should use the reporturl setting's host, port and ssl option" do
      uri = URI.parse(Puppet[:reporturl])
      ssl = (uri.scheme == 'https')
      Net::HTTP.expects(:new).with(
        uri.host, uri.port, optionally(anything, anything)
      ).returns http
      http.expects(:use_ssl=).with(ssl)
      subject.process
    end

    it "uses ssl if reporturl has the https protocol" do
      Puppet[:reporturl] = "https://myhost.mydomain:1234/report/upload"
      uri = URI.parse(Puppet[:reporturl])
      Net::HTTP.expects(:new).with(
        uri.host, uri.port, optionally(anything, anything)
      ).returns http
      http.expects(:use_ssl=).with(true)
      subject.process
    end

    it "does not use ssl if reporturl has plain http protocol" do
      Puppet[:reporturl] = "http://myhost.mydomain:1234/report/upload"
      uri = URI.parse(Puppet[:reporturl])
      Net::HTTP.expects(:new).with(
        uri.host, uri.port, optionally(anything, anything)
      ).returns http
      http.expects(:use_ssl=).with(false)
      subject.process
    end
  end

  describe "when making a request" do
    let(:http) { stub_everything "http" }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }

    before :each do
      Net::HTTP.expects(:new).returns(http)
    end

    it "should use the path specified by the 'reporturl' setting" do
      http.expects(:post).with {|path, data, headers|
        path.should == URI.parse(Puppet[:reporturl]).path
      }.returns(httpok)

      subject.process
    end

    it "should give the body as the report as YAML" do
      http.expects(:post).with {|path, data, headers|
        data.should == subject.to_yaml
      }.returns(httpok)

      subject.process
    end

    it "should set content-type to 'application/x-yaml'" do
      http.expects(:post).with {|path, data, headers|
        headers["Content-Type"].should == "application/x-yaml"
      }.returns(httpok)

      subject.process
    end

    Net::HTTPResponse::CODE_TO_OBJ.each do |code, klass|
      if code.to_i >= 200 and code.to_i < 300
        it "should succeed on http code #{code}" do
          response = klass.new('1.1', code, '')
          http.expects(:post).returns(response)

          Puppet.expects(:err).never
          subject.process
        end
      end

      if code.to_i >= 300
        it "should log error on http code #{code}" do
          response = klass.new('1.1', code, '')
          http.expects(:post).returns(response)

          Puppet.expects(:err)
          subject.process
        end
      end
    end

  end
end
