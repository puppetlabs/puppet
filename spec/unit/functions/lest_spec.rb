require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the lest function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'calls a lambda passing no argument' do
    expect(compile_to_catalog("lest(undef) || { notify { testing: } }")).to have_resource('Notify[testing]')
  end

  it 'produces what lambda returns if value is undef' do
    expect(compile_to_catalog("notify{ lest(undef) || { testing }: }")).to have_resource('Notify[testing]')
  end

  it 'does not call lambda if argument is not undef' do
    expect(compile_to_catalog('lest(1) || { notify { "failed": } }')).to_not have_resource('Notify[failed]')
  end

  it 'produces given argument if given not undef' do
    expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test_yay_ing]')
    notify{ "test${lest('_yay_') || { '_oh_no_' }}ing": }
    SOURCE
  end

  it 'errors when lambda wants too many args' do
    expect do
      compile_to_catalog('lest(1) |$x| { }')
    end.to raise_error(/'lest' block expects no arguments, got 1/m)
  end

end
