require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the scanf function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  before :each do
    Puppet[:parser] = 'future'
  end

  it 'scans a value and returns an array' do
    expect(compile_to_catalog("$x = '42'.scanf('%i')[0] + 1; notify { \"test$x\": }")).to have_resource('Notify[test43]')
  end

  it 'scans a value and returns result of a code block' do
    expect(compile_to_catalog("$x = '42'.scanf('%i')|$x|{$x[0]} + 1; notify { \"test$x\": }")).to have_resource('Notify[test43]')
  end

  it 'returns empty array if nothing was scanned' do
    expect(compile_to_catalog("$x = 'no'.scanf('%i')[0]; notify { \"test${x}test\": }")).to have_resource('Notify[testtest]')
  end

  it 'produces result up to first unsuccessful scan' do
    expect(compile_to_catalog("$x = '42 no'.scanf('%i'); notify { \"test${x[0]}${x[1]}test\": }")).to have_resource('Notify[test42test]')
  end


  it 'errors when not given enough arguments' do
    expect do
      compile_to_catalog("'42'.scanf()")
    end.to raise_error(/.*expected.*scanf\(String data, String format, Callable block \{0,1\}\)/m)
  end
end
