#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/reports'

# FakeHTTP fakes the behavior of Net::HTTP#request and acts as a sensor for an
# otherwise difficult to trace method call.
#
class FakeHTTP
  REQUESTS = {}
  def self.request(req)
    REQUESTS[req.path] = req
  end
end

processor = Puppet::Reports.report(:http)

describe processor do
  before  { Net::HTTP.any_instance.stubs(:start).yields(FakeHTTP) }
  subject { Puppet::Transaction::Report.new("apply").extend(processor) }

  it { should respond_to(:process) }

  it "should use the reporturl setting's host and port" do
    uri = URI.parse(Puppet[:reporturl])
    Net::HTTP.expects(:new).with(uri.host, uri.port).returns(stub_everything('http'))
    subject.process
  end

  describe "request" do
    before { subject.process }

    describe "path" do
      it "should use the path specified by the 'reporturl' setting" do
        reports_request.path.should == URI.parse(Puppet[:reporturl]).path
      end
    end

    describe "body" do
      it "should be the report as YAML" do
        reports_request.body.should == subject.to_yaml
      end
    end

    describe "content type" do
      it "should be 'application/x-yaml'" do
        reports_request.content_type.should == "application/x-yaml"
      end
    end
  end

  private

  def reports_request; FakeHTTP::REQUESTS[URI.parse(Puppet[:reporturl]).path] end
end
