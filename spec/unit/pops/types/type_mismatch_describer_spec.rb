require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

describe 'the type mismatch describer' do
  include PuppetSpec::Compiler

  it 'will report a mismatch between a hash and a struct with details' do
    code = <<-CODE
      function f(Hash[String,String] $h) {
         $h['a']
      }
      f({'a' => 'a', 'b' => 23})
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects a Hash\[String, String\] value, got Struct\[\{'a'=>String, 'b'=>Integer\}\]/)
  end

  it 'will report a mismatch between a array and tuple with details' do
    code = <<-CODE
      function f(Array[String] $h) {
         $h[0]
      }
      f(['a', 23])
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects an Array\[String\] value, got Tuple\[String, Integer\]/)
  end

  it 'will not report a mismatch between a array and struct with details' do
    code = <<-CODE
      function f(Array[String] $h) {
         $h[0]
      }
      f({'a' => 'a string', 'b' => 23})
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects an Array value, got Struct/)
  end

  it 'will not report a mismatch between a hash and tuple with details' do
    code = <<-CODE
      function f(Hash[String,String] $h) {
         $h['a']
      }
      f(['a', 23])
    CODE
    expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects a Hash value, got Tuple/)
  end

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
