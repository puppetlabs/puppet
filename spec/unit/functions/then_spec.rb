require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the then function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'calls a lambda passing one argument' do
    expect(compile_to_catalog("then(testing) |$x| { notify { $x: } }")).to have_resource('Notify[testing]')
  end

  it 'produces what lambda returns if value is not undef' do
    expect(compile_to_catalog("notify{ then(1) |$x| { testing }: }")).to have_resource('Notify[testing]')
  end

  it 'does not call lambda if argument is undef' do
    expect(compile_to_catalog('then(undef) |$x| { notify { "failed": } }')).to_not have_resource('Notify[failed]')
  end

  it 'produces undef if given value is undef' do
    expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test-Undef-ing]')
    notify{ "test-${type(then(undef) |$x| { testing })}-ing": }
    SOURCE
  end

  it 'errors when lambda wants too many args' do
    expect do
      compile_to_catalog('then(1) |$x, $y| { }')
    end.to raise_error(/'then' block expects 1 argument, got 2/m)
  end

  it 'errors when lambda wants too few args' do
    expect do
      compile_to_catalog('then(1) || { }')
    end.to raise_error(/'then' block expects 1 argument, got none/m)
  end

end
