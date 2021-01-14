require 'spec_helper'
require 'puppet_spec/compiler'

describe Puppet::Pops::Evaluator::DeferredResolver do
  include PuppetSpec::Compiler

  let(:environment) { Puppet::Node::Environment.create(:testing, []) }
  let(:facts) { Puppet::Node::Facts.new('node.example.com') }

  it 'resolves deferred values in a catalog' do
    catalog = compile_to_catalog(<<~END)
      notify { "deferred":
        message => Deferred("join", [[1,2,3], ":"])
      }
    END
    described_class.resolve_and_replace(facts, catalog)

    expect(catalog.resource(:notify, 'deferred')[:message]).to eq('1:2:3')
  end
end
