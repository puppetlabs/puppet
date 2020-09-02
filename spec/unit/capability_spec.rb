require 'spec_helper'
require 'puppet_spec/compiler'

describe 'Capability types' do
  include PuppetSpec::Compiler
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:node) { Puppet::Node.new('test', :environment => env) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }

  before(:each) do
    allow_any_instance_of(Puppet::Parser::Compiler).to receive(:loaders).and_return(loaders)
    Puppet.push_context({:loaders => loaders, :current_environment => env})
    Puppet::Type.newtype :cap, :is_capability => true do
      newparam :name
      newparam :host
    end
  end

  after(:each) do
    Puppet::Type.rmtype(:cap)
    Puppet.pop_context()
  end

  context 'annotations' do
    it "raises a syntax error on 'produces'" do
      expect {
        compile_to_catalog(<<-MANIFEST, node)
        define test($hostname) {
          notify { "hostname ${hostname}":}
        }

        Test produces Cap {
          host => $hostname
        }
        MANIFEST
      }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at 'produces'/)
    end

    it "raises a syntax error on 'consumes'" do
      expect {
        compile_to_catalog(<<-MANIFEST, node)
        define test($hostname) {
          notify { "hostname ${hostname}":}
        }

        Test consumes Cap {
          host => $hostname
        }
        MANIFEST
      }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at 'consumes'/)
    end
  end

  context 'capability metaparameters' do
    def make_catalog(instance)
      manifest = <<-MANIFEST
      define test($hostname = nohost) {
        notify { "hostname ${hostname}":}
      }
    MANIFEST

      compile_to_catalog(manifest + instance, node)
    end

    ['export', 'consume'].each do |metaparam|

      it "validates that #{metaparam} metaparameter rejects values that are not resources" do
        expect { make_catalog("test { one: #{metaparam} => 'hello' }") }.to raise_error(Puppet::Error, /not a resource/)
      end

      it "validates that #{metaparam} metaparameter rejects resources that are not capability resources" do
        expect { make_catalog("notify{hello:} test { one: #{metaparam} => Notify[hello] }") }.to raise_error(Puppet::Error, /not a capability resource/)
      end
    end
  end
end
