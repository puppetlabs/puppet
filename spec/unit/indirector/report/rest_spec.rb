#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/report/rest'

describe Puppet::Transaction::Report::Rest do
  it "should be a subclass of Puppet::Indirector::REST" do
    Puppet::Transaction::Report::Rest.superclass.should equal(Puppet::Indirector::REST)
  end

  it "should use the :report_server setting in preference to :server" do
    Puppet.settings[:server] = "server"
    Puppet.settings[:report_server] = "report_server"
    Puppet::Transaction::Report::Rest.server.should == "report_server"
  end

  it "should have a value for report_server and report_port" do
    Puppet::Transaction::Report::Rest.server.should_not be_nil
    Puppet::Transaction::Report::Rest.port.should_not be_nil
  end

  it "should use the :report SRV service" do
    Puppet::Transaction::Report::Rest.srv_service.should == :report
  end

  let(:model) { Puppet::Transaction::Report }
  let(:terminus_class) { Puppet::Transaction::Report::Rest }
  let(:terminus) { model.indirection.terminus(:rest) }
  let(:indirection) { model.indirection }

  before(:each) do
    Puppet::Transaction::Report.indirection.terminus_class = :rest
  end

  def mock_response(code, body, content_type='text/plain', encoding=nil)
    obj = stub('http 200 ok', :code => code.to_s, :body => body)
    obj.stubs(:[]).with('content-type').returns(content_type)
    obj.stubs(:[]).with('content-encoding').returns(encoding)
    obj.stubs(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).returns(Puppet.version)
    obj
  end

  def save_request(key, instance, options={})
    Puppet::Indirector::Request.new(:report, :find, key, instance, options)
  end

  describe "#save" do
    let(:http_method) { :put }
    let(:response) { mock_response(200, 'body') }
    let(:connection) { stub('mock http connection', :put => response, :verify_callback= => nil) }
    let(:instance) { model.new('the thing', 'some contents') }
    let(:request) { save_request(instance.name, instance) }

    before :each do
      terminus.stubs(:network).returns(connection)
    end

    it "deserializes the response as an array of report processor names" do
      processors = ["store", "http"]
      body = YAML.dump(processors)
      response = mock_response('200', body, 'text/yaml')
      connection.expects(:put).returns response

      terminus.save(request).should == ["store", "http"]
    end
  end
end
