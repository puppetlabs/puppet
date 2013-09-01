require 'spec_helper'
require 'puppet/pops'

describe 'Puppet::Pops::Types::PPatternType' do
  it 'can create a regular expression via the [] operator' do
    result = Puppet::Pops::Types::PPatternType.new()['a*']
    expect(result.class).to eql(Regexp)
    expect(result).to eql(Regexp.new('a*'))
  end
end