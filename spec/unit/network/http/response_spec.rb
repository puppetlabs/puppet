#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet_spec/handler'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Response do
  let(:handler) { PuppetSpec::Handler.new }
  let(:response) { {} }
  let(:subject) { described_class.new(handler, response) }
  let(:body) { JSON.dump({ "foo" => "bar"}) }

  it "passes the status code and body to the handler" do
    handler.expects(:set_response).with(response, body, 200)

    subject.respond_with(200, 'application/json', body)
  end

  context "content types" do
    it "accepts content-type as a mime string" do
      handler.expects(:set_content_type).with(response, 'application/json')

      subject.respond_with(200, 'application/json', body)
    end

    it "accepts content-type as a format object" do
      formatter = Puppet::Network::FormatHandler.format(:json)
      handler.expects(:set_content_type).with(response, formatter)

      subject.respond_with(200, formatter, body)
    end
  end
end
