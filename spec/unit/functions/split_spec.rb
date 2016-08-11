require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the split function' do

  before(:all) do
    loaders = Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))
    Puppet.push_context({:loaders => loaders}, "test-examples")
  end

  after(:all) do
    Puppet::Pops::Loaders.clear
    Puppet::pop_context()
  end

  def split(*args)
    Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'split').call({}, *args)
  end

  let(:type_parser) { Puppet::Pops::Types::TypeParser.singleton }

  it 'should raise an Error if there is less than 2 arguments' do
    expect { split('a,b') }.to raise_error(/'split' expects 2 arguments, got 1/)
  end

  it 'should raise an Error if there is more than 2 arguments' do
    expect { split('a,b','foo', 'bar') }.to raise_error(/'split' expects 2 arguments, got 3/)
  end

  it 'should raise a RegexpError if the regexp is malformed' do
    expect { split('a,b',')') }.to raise_error(/unmatched close parenthesis/)
  end

  it 'should handle pattern in string form' do
    expect(split('a,b',',')).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp form' do
    expect(split('a,b',/,/)).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp Type form' do
    expect(split('a,b',type_parser.parse('Regexp[/,/]'))).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp Type form with empty regular expression' do
    expect(split('ab',type_parser.parse('Regexp[//]'))).to eql(['a', 'b'])
  end

  it 'should handle pattern in Regexp Type form with missing regular expression' do
    expect(split('ab',type_parser.parse('Regexp'))).to eql(['a', 'b'])
  end
end
