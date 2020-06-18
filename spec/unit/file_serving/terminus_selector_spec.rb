require 'spec_helper'

require 'puppet/file_serving/terminus_selector'

describe Puppet::FileServing::TerminusSelector do
  class TestSelector
    include Puppet::FileServing::TerminusSelector
  end

  def create_request(key)
    Puppet::Indirector::Request.new(:indirection_name, :find, key, nil, {node: 'whatever'})
  end

  subject { TestSelector.new }

  describe "when being used to select termini" do
    it "should return :file if the request key is fully qualified" do
      request = create_request(File.expand_path('/foo'))

      expect(subject.select(request)).to eq(:file)
    end

    it "should return :file_server if the request key is relative" do
      request = create_request('modules/my_module/path/to_file')

      expect(subject.select(request)).to eq(:file_server)
    end

    it "should return :file if the URI protocol is set to 'file'" do
      request = create_request(Puppet::Util.path_to_uri(File.expand_path("/foo")).to_s)

      expect(subject.select(request)).to eq(:file)
    end

    it "should return :http if the URI protocol is set to 'http'" do
      request = create_request("http://www.example.com")

      expect(subject.select(request)).to eq(:http)
    end

    it "should return :http if the URI protocol is set to 'https'" do
      request = create_request("https://www.example.com")

      expect(subject.select(request)).to eq(:http)
    end

    it "should return :http if the path starts with a double slash" do
      request = create_request("https://www.example.com//index.html")

      expect(subject.select(request)).to eq(:http)
    end

    it "should fail when a protocol other than :puppet, :http(s) or :file is used" do
      request = create_request("ftp://ftp.example.com")

      expect {
        subject.select(request)
      }.to raise_error(ArgumentError, /URI protocol 'ftp' is not currently supported for file serving/)
    end

    describe "and the protocol is 'puppet'" do
      it "should choose :rest when a server is specified" do
        request = create_request("puppet://puppetserver.example.com")

        expect(subject.select(request)).to eq(:rest)
      end

      # This is so a given file location works when bootstrapping with no server.
      it "should choose :rest when default_file_terminus is rest" do
        Puppet[:server] = 'localhost'
        request = create_request("puppet:///plugins")

        expect(subject.select(request)).to eq(:rest)
      end

      it "should choose :file_server when default_file_terminus is file_server and no server is specified on the request" do
        Puppet[:default_file_terminus] = 'file_server'
        request = create_request("puppet:///plugins")

        expect(subject.select(request)).to eq(:file_server)
      end
    end
  end
end
