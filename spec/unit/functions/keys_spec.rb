require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the keys function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'returns the keys in the hash in the order they appear in a hash iteration' do
    expect(compile_to_catalog(<<-'SRC'.unindent)).to have_resource('Notify[apples & oranges]')
        $k = {'apples' => 1, 'oranges' => 2}.keys
        notify { "${k[0]} & ${k[1]}": }
      SRC
  end

  it 'returns an empty array for an empty hash' do
    expect(compile_to_catalog(<<-'SRC'.unindent)).to have_resource('Notify[0]')
        $v = {}.keys.reduce(0) |$m, $v| { $m+1 }
        notify { "${v}": }
      SRC
  end

  it 'includes an undef key if one is present in the hash' do
    expect(compile_to_catalog(<<-'SRC'.unindent)).to have_resource('Notify[Undef]')
        $types = {undef => 1}.keys.map |$v| { $v.type }
        notify { "${types[0]}": }
      SRC
  end

end
