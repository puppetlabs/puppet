require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

describe 'the type mismatch describer' do
  include PuppetSpec::Compiler

  it 'will report a mismatch against an aliased type correctly' do
    code = <<-CODE
      type UnprivilegedPort = Integer[1024,65537]

      function check_port(UnprivilegedPort $port) {
         $port
      }
      check_port(34)
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /parameter 'port' expects an UnprivilegedPort value, got Integer\[34, 34\]/)
  end
end
