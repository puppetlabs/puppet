#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/reports'

processor = Puppet::Reports.report(:http)

describe processor do
  subject { Puppet::Transaction::Report.new("apply").extend(processor) }

  it "should use the reporturl setting's host and port" do
    uri = URI.parse(Puppet[:reporturl])
    Net::HTTP.expects(:new).with(uri.host, uri.port).returns(stub_everything('http'))
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
