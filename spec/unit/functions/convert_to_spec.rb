require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the convert_to function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'converts and returns the converted when no lambda is given' do
    expect(compile_to_catalog('notify{ "testing-${[a,1].convert_to(Hash) =~ Hash}": }')).to have_resource('Notify[testing-true]')
  end

  it 'converts given value to instance of type and calls a lambda with converted value' do
    expect(compile_to_catalog('"1".convert_to(Integer) |$x| { notify { "testing-${x.type(generalized)}": } }')).to have_resource('Notify[testing-Integer]')
  end

  it 'returns the lambda return when lambda is given' do
    expect(compile_to_catalog('notify{ "testing-${[a,1].convert_to(Hash) |$x| { yay }}": }')).to have_resource('Notify[testing-yay]')
  end

end
