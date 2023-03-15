require 'spec_helper'
require 'puppet/indirector/rest'

class Puppet::TestModel
  extend Puppet::Indirector
  indirects :test_model
end

# The subclass must not be all caps even though the superclass is
class Puppet::TestModel::Rest < Puppet::Indirector::REST
end

class Puppet::FailingTestModel
  extend Puppet::Indirector
  indirects :failing_test_model
end

# The subclass must not be all caps even though the superclass is
class Puppet::FailingTestModel::Rest < Puppet::Indirector::REST
  def find(request)
    http = Puppet.runtime[:http]
    response = http.get(URI('http://puppet.example.com:8140/puppet/v3/failing_test_model'))

    if response.code == 404
      return nil unless request.options[:fail_on_404]

      _, body = parse_response(response)
      msg = _("Find %{uri} resulted in 404 with the message: %{body}") % { uri: elide(response.url.path, 100), body: body }
      raise Puppet::Error, msg
    else
      raise convert_to_http_error(response)
    end
  end
end

describe Puppet::Indirector::REST do
  before :each do
    Puppet::TestModel.indirection.terminus_class = :rest
  end

  it "raises when find is called" do
    expect {
      Puppet::TestModel.indirection.find('foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when head is called" do
    expect {
      Puppet::TestModel.indirection.head('foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when search is called" do
    expect {
      Puppet::TestModel.indirection.search('foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when save is called" do
    expect {
      Puppet::TestModel.indirection.save(Puppet::TestModel.new, 'foo')
    }.to raise_error(NotImplementedError)
  end

  it "raises when destroy is called" do
    expect {
      Puppet::TestModel.indirection.destroy('foo')
    }.to raise_error(NotImplementedError)
  end

  context 'when parsing the response error' do
    before :each do
      Puppet::FailingTestModel.indirection.terminus_class = :rest
    end

    it 'returns nil if 404 is returned and fail_on_404 is omitted' do
      stub_request(:get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model').to_return(status: 404)

      expect(Puppet::FailingTestModel.indirection.find('foo')).to be_nil
    end

    it 'raises if 404 is returned and fail_on_404 is true' do
      stub_request(
        :get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model',
      ).to_return(status: 404,
                  headers: { 'Content-Type' => 'text/plain' },
                  body: 'plaintext')

      expect {
        Puppet::FailingTestModel.indirection.find('foo', fail_on_404: true)
      }.to raise_error(Puppet::Error, 'Find /puppet/v3/failing_test_model resulted in 404 with the message: plaintext')
    end

    it 'returns the HTTP reason if the response body is empty' do
      stub_request(:get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model').to_return(status: [500, 'Internal Server Error'])

      expect {
        Puppet::FailingTestModel.indirection.find('foo')
      }.to raise_error(Net::HTTPError, 'Error 500 on SERVER: Internal Server Error')
    end

    it 'parses the response body as text' do
      stub_request(
        :get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model'
      ).to_return(status: [500, 'Internal Server Error'],
                  headers: { 'Content-Type' => 'text/plain' },
                  body: 'plaintext')

      expect {
        Puppet::FailingTestModel.indirection.find('foo')
      }.to raise_error(Net::HTTPError, 'Error 500 on SERVER: plaintext')
    end

    it 'parses the response body as json and returns the "message"' do
      stub_request(
        :get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model'
      ).to_return(status: [500, 'Internal Server Error'],
                  headers: { 'Content-Type' => 'application/json' },
                  body: JSON.dump({'status' => false, 'message' => 'json error'}))

      expect {
        Puppet::FailingTestModel.indirection.find('foo')
      }.to raise_error(Net::HTTPError, 'Error 500 on SERVER: json error')
    end

    it 'parses the response body as pson and returns the "message"', if: Puppet.features.pson? do
      stub_request(
        :get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model'
      ).to_return(status: [500, 'Internal Server Error'],
                  headers: { 'Content-Type' => 'application/pson' },
                  body: PSON.dump({'status' => false, 'message' => 'pson error'}))

      expect {
        Puppet::FailingTestModel.indirection.find('foo')
      }.to raise_error(Net::HTTPError, 'Error 500 on SERVER: pson error')
    end

    it 'returns the response body if no content-type given' do
      stub_request(
        :get, 'http://puppet.example.com:8140/puppet/v3/failing_test_model'
      ).to_return(status: [500, 'Internal Server Error'],
                  body: 'unknown text')

      expect {
        Puppet::FailingTestModel.indirection.find('foo')
      }.to raise_error(Net::HTTPError, 'Error 500 on SERVER: unknown text')
    end
  end
end
