require 'spec_helper'
require 'puppet/pops'
require 'stringio'
require 'puppet_spec/scope'

describe "lookup function" do
  include PuppetSpec::Scope

  let :scope do create_test_scope_for_node('foo') end

  it 'should raise an error since this function is converted to 4x API)' do
    expect { scope.function_lookup(['key']) }.to raise_error(Puppet::ParseError, /converted to 4x API/)
  end
end
