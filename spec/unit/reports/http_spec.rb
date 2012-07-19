#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/reports'

processor = Puppet::Reports.report(:http)

describe processor do
  subject { Puppet::Transaction::Report.new("apply").extend(processor) }

  it "should use the reporturl setting's host, port and ssl option" do
    uri = URI.parse(Puppet[:reporturl])
    ssl = (uri.scheme == 'https')
    Puppet::Network::HttpPool.expects(:http_instance).with(uri.host, uri.port, use_ssl=ssl).returns(stub_everything('http'))
    subject.process
  end

  it "should use ssl if requested" do
    Puppet[:reporturl] = Puppet[:reporturl].sub(/^http:\/\//, 'https://')
    uri = URI.parse(Puppet[:reporturl])
    Puppet::Network::HttpPool.expects(:http_instance).with(uri.host, uri.port, use_ssl=true).returns(stub_everything('http'))
    subject.process
  end

  it "should use the report timeout for posting http reports" do
    timeout = Puppet[:reporturl_timeout] = 40
    uri = URI.parse(Puppet[:reporturl])
    ssl = (uri.scheme == 'https')
    Puppet::Network::HttpPool.expects(:http_instance).with(uri.host, uri.port, use_ssl = ssl).returns(stub_everything('http')) { |http|
        http.read_timeout == timeout
        http.open_timeout == timeout
    }
    subject.process
  end


  describe "when making a request" do
    let(:http) { mock "http" }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }

    before :each do
      Net::HTTP.any_instance.expects(:start).yields(http)
    end

    it "should use the path specified by the 'reporturl' setting" do
      http.expects(:request).with {|req|
        req.path.should == URI.parse(Puppet[:reporturl]).path
      }.returns(httpok)

      subject.process
    end

    it "should give the body as the report as YAML" do
      http.expects(:request).with {|req|
        req.body.should == subject.to_yaml
      }.returns(httpok)

      subject.process
    end

    it "should set content-type to 'application/x-yaml'" do
      http.expects(:request).with {|req|
        req.content_type.should == "application/x-yaml"
      }.returns(httpok)

      subject.process
    end

    Net::HTTPResponse::CODE_TO_OBJ.each do |code, klass|
      if code.to_i >= 200 and code.to_i < 300
        it "should succeed on http code #{code}" do
          response = klass.new('1.1', code, '')
          http.expects(:request).returns(response)

          Puppet.expects(:err).never
          subject.process
        end
      end

      if code.to_i >= 300
        it "should log error on http code #{code}" do
          response = klass.new('1.1', code, '')
          http.expects(:request).returns(response)

          Puppet.expects(:err)
          subject.process
        end
      end
    end

  end
end
