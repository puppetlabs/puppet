#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/reports'

class Net::HTTP
    REQUESTS = {}
    alias_method :old_request, :request
    def request(req, body=nil, &block)
        REQUESTS[req.path] = req
        old_request(req, body, &block)
    end
end

processor = Puppet::Reports.report(:http)

describe processor do
    subject { Puppet::Transaction::Report.new.extend(processor) }

    it { should respond_to(:process) }

    describe "request" do
        before { subject.process }

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

    def reports_request; Net::HTTP::REQUESTS[URI.parse(Puppet[:reporturl]).path] end
end
