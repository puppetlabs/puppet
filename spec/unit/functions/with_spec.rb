require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the with function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  before :each do
    Puppet[:parser] = 'future'
  end

  it 'calls a lambda passing no arguments' do
    expect(compile_to_catalog("with() || { notify { testing: } }")).to have_resource('Notify[testing]')
  end

  it 'calls a lambda passing a single argument' do
    expect(compile_to_catalog('with(1) |$x| { notify { "testing$x": } }')).to have_resource('Notify[testing1]')
  end

  it 'calls a lambda passing more than one argument' do
    expect(compile_to_catalog('with(1, 2) |*$x| { notify { "testing${x[0]}, ${x[1]}": } }')).to have_resource('Notify[testing1, 2]')
  end

  it 'errors when not given enough arguments for the lambda' do
    expect do
      compile_to_catalog('with(1) |$x, $y| { }')
    end.to raise_error(/Too few arguments/)
  end
end
