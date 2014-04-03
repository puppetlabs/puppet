require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Evaluator::Scopes do
  it "tracks fully qualified variables in the global scope" do
    scopes = Puppet::Pops::Evaluator::Scopes.new

    scopes.bind_global("a::b", 1)

    expect(scopes.global.lookup("a::b")).to eq(1)
  end
end
