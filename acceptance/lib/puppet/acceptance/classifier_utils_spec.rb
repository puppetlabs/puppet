require File.join(File.dirname(__FILE__),'../../acceptance_spec_helper.rb')
require 'puppet/acceptance/classifier_utils'
require 'stringio'
require 'beaker'

module ClassifierUtilsSpec
describe 'ClassifierUtils' do

  class ATestCase < Beaker::TestCase
    include Puppet::Acceptance::ClassifierUtils
    attr_accessor :logger, :hosts

    def initialize
      @logger = Logger.new
      @hosts = []
    end

    def logger
      @logger
    end

    def teardown
    end

    class Logger
      attr_reader :destination

      def initialize
        @destination = StringIO.new
      end

      def info(log)
        @destination << (log)
      end
    end
  end

  let(:testcase) { ATestCase.new }
  let(:handle) { testcase.classifier_handle(
      :server => 'foo',
      :cert => 'cert',
      :key => 'key',
      :ca_cert_file => 'file'
    )
  }

  it "provides a handle to the classifier service" do
    handle.expects(:perform_request).with(Net::HTTP::Get, '/hi', {})
    handle.get('/hi')
  end

  it "logs output from the http connection attempt" do
    TCPSocket.expects(:open).raises('no-connection')
    OpenSSL::X509::Certificate.expects(:new).with('certkey').returns(stub('cert'))
    OpenSSL::PKey::RSA.expects(:new).with('certkey', nil).returns(stub('key'))
    expect { handle.get('/hi') }.to raise_error('no-connection')
    expect(testcase.logger.destination.string).to match(/opening connection to foo/)
  end

  it "creates an agent-specified environment group for a passed set of nodes" do
    nodes = [
      stub_everything('master', :hostname => 'abcmaster', :[] => ['master'] ),
      stub_everything('agent', :hostname => 'defagent', :[] => ['agent'] ),
    ]
    testcase.hosts = nodes

    uuid = nil
    handle.expects(:perform_request).with do |method,url,body_hash|
      expect(method).to eq(Net::HTTP::Put)
      test_regex = %r{/v1/groups/(\w+-\w+-\w+-\w+-\w+)}
      md = test_regex.match(url)
      expect(uuid = md[1]).to_not be_nil
      expect(body_hash[:body]).to match(/environment[^:]*:[^:]*agent-specified/)
    end.returns(
        stub_everything('response', :code => 201))

    expect(testcase.classify_nodes_as_agent_specified(nodes).to_s).to eq(uuid)
  end
end
end
