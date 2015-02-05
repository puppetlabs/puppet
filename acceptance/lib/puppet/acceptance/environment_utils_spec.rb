require File.join(File.dirname(__FILE__),'../../acceptance_spec_helper.rb')
require 'puppet/acceptance/environment_utils'

module EnvironmentUtilsSpec
describe 'EnvironmentUtils' do
  class ATestCase
    include Puppet::Acceptance::EnvironmentUtils

    def step(str)
      yield
    end

    def on(host, command, options = nil)
      stdout = host.do(command, options)
      yield TestResult.new(stdout) if block_given?
    end
  end

  class TestResult
    attr_accessor :stdout

    def initialize(stdout)
      self.stdout = stdout
    end
  end

  class TestHost
    attr_accessor :did, :directories, :attributes

    def initialize(directories, attributes = {})
      self.directories = directories
      self.did = []
      self.attributes = attributes
    end

    def do(command, options)
      did << (options.nil? ? command : [command, options])
      case command
      when /^ls (.*)/ then directories[$1]
      end
    end

    def [](param)
      attributes[param]
    end
  end

  let(:testcase) { ATestCase.new }
  let(:host) { TestHost.new(directory_contents, 'user' => 'root', 'group' => 'puppet') }
  let(:directory_contents) do
    {
      '/etc/puppetlabs' => 'foo bar baz widget',
      '/tmp/dir'    => 'foo dingo bar thing',
    }
  end

  it "runs the block of code" do
    ran_code = false
    testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') do
      ran_code = true
    end
    expect(ran_code).to be true
    expect(host.did).to eq([
      "ls /etc/puppetlabs",
      "ls /tmp/dir",
      "mv /etc/puppetlabs/foo /etc/puppetlabs/foo.bak",
      "mv /etc/puppetlabs/bar /etc/puppetlabs/bar.bak",
      "cp -R /tmp/dir/foo /etc/puppetlabs/foo",
      "cp -R /tmp/dir/dingo /etc/puppetlabs/dingo",
      "cp -R /tmp/dir/bar /etc/puppetlabs/bar",
      "cp -R /tmp/dir/thing /etc/puppetlabs/thing",
      "chown -R root:puppetlabs /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "chmod -R 770 /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "rm -rf /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "mv /etc/puppetlabs/foo.bak /etc/puppetlabs/foo",
      "mv /etc/puppetlabs/bar.bak /etc/puppetlabs/bar"
    ])
  end

  it "backs up the original items that are shadowed by tmp items" do
    testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') {}
    expect(host.did.grep(%r{mv /etc/puppetlabs/\w+ })).to eq([
      "mv /etc/puppetlabs/foo /etc/puppetlabs/foo.bak",
      "mv /etc/puppetlabs/bar /etc/puppetlabs/bar.bak",
    ])
  end

  it "copies in all the tmp items into the working dir" do
    testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') {}
    expect(host.did.grep(%r{cp})).to eq([
      "cp -R /tmp/dir/foo /etc/puppetlabs/foo",
      "cp -R /tmp/dir/dingo /etc/puppetlabs/dingo",
      "cp -R /tmp/dir/bar /etc/puppetlabs/bar",
      "cp -R /tmp/dir/thing /etc/puppetlabs/thing",
    ])
  end

  it "opens the permissions on all copied files to 770 and sets ownership based on host settings" do
    testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') {}
    expect(host.did.grep(%r{ch(mod|own)})).to eq([
      "chown -R root:puppet /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "chmod -R 770 /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
    ])
  end

  it "deletes all the tmp items from the working dir" do
    testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') {}
    expect(host.did.grep(%r{rm})).to eq([
      "rm -rf /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
    ])
  end

  it "replaces the original items that had been shadowed into the working dir" do
    testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') {}
    expect(host.did.grep(%r{mv /etc/puppetlabs/\w+\.bak})).to eq([
      "mv /etc/puppetlabs/foo.bak /etc/puppetlabs/foo",
      "mv /etc/puppetlabs/bar.bak /etc/puppetlabs/bar"
    ])
  end

  it "always cleans up, even if the code we yield to raises an error" do
    expect do
      testcase.safely_shadow_directory_contents_and_yield(host, '/etc/puppetlabs', '/tmp/dir') do
        raise 'oops'
      end
    end.to raise_error('oops')
    expect(host.did).to eq([
      "ls /etc/puppetlabs",
      "ls /tmp/dir",
      "mv /etc/puppetlabs/foo /etc/puppetlabs/foo.bak",
      "mv /etc/puppetlabs/bar /etc/puppetlabs/bar.bak",
      "cp -R /tmp/dir/foo /etc/puppetlabs/foo",
      "cp -R /tmp/dir/dingo /etc/puppetlabs/dingo",
      "cp -R /tmp/dir/bar /etc/puppetlabs/bar",
      "cp -R /tmp/dir/thing /etc/puppetlabs/thing",
      "chown -R root:puppetlabs /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "chmod -R 770 /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "rm -rf /etc/puppetlabs/foo /etc/puppetlabs/dingo /etc/puppetlabs/bar /etc/puppetlabs/thing",
      "mv /etc/puppetlabs/foo.bak /etc/puppetlabs/foo",
      "mv /etc/puppetlabs/bar.bak /etc/puppetlabs/bar"
    ])
  end
end
end
