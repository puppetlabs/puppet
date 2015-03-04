require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the regsubst function' do

  before(:all) do
    loaders = Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, []))
    Puppet.push_context({:loaders => loaders}, "test-examples")
  end

  after(:all) do
    Puppet::Pops::Loaders.clear
    Puppet::pop_context()
  end

  def regsubst(*args)
    Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'regsubst').call({}, *args)
  end

  let(:type_parser) { Puppet::Pops::Types::TypeParser.new }

  context 'when using a string pattern' do
    it 'should raise an Error if there is less than 3 arguments' do
      expect { regsubst('foo', 'bar') }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should raise an Error if there is more than 5 arguments' do
      expect { regsubst('foo', 'bar', 'gazonk', 'G', 'U', 'y') }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should raise an Error if given a bad flag' do
      expect { regsubst('foo', 'bar', 'gazonk', 'X') }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should raise an Error if given a bad encoding' do
      expect { regsubst('foo', 'bar', 'gazonk', nil, 'X') }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should raise an Error if given a bad regular expression' do
      expect { regsubst('foo', '(', 'gazonk') }.to raise_error(/pattern with unmatched parenthesis/)
    end

    it 'should handle case insensitive flag' do
      expect(regsubst('the monkey breaks baNAna trees', 'b[an]+a', 'coconut', 'I')).to eql('the monkey breaks coconut trees')
    end
  end

  context 'when using a regexp pattern' do
    it 'should raise an Error if there is less than 3 arguments' do
      expect { regsubst('foo', /bar/) }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should raise an Error if there is more than 4 arguments' do
      expect { regsubst('foo', /bar/, 'gazonk', 'G', 'y') }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should raise an Error if given a flag other thant G' do
      expect { regsubst('foo', /bar/, 'gazonk', 'I') }.to raise_error(/called with mis-matched arguments/)
    end

    it 'should handle global substitutions' do
      expect(regsubst("the monkey breaks\tbanana trees", /[ \t]/, '--', 'G')).to eql('the--monkey--breaks--banana--trees')
    end

    it 'should accept Type[Regexp]' do
      expect(regsubst('abc', type_parser.parse("Regexp['b']"), '_')).to eql('a_c')
    end
  end

  context 'when using an array target' do

    it 'should perform substitutions in all elements and return array when using regexp pattern' do
      expect(regsubst(['a#a', 'b#b', 'c#c'], /#/, '_')).to eql(['a_a', 'b_b', 'c_c'])
    end

    it 'should perform substitutions in all elements when using string pattern' do
      expect(regsubst(['a#a', 'b#b', 'c#c'], '#', '_')).to eql(['a_a', 'b_b', 'c_c'])
    end

    it 'should perform substitutions in all elements when using Type[Regexp] pattern' do
      expect(regsubst(['a#a', 'b#b', 'c#c'], type_parser.parse('Regexp[/#/]'), '_')).to eql(['a_a', 'b_b', 'c_c'])
    end

    it 'should handle global substitutions with groups on all elements' do
      expect(regsubst(
                 ['130.236.254.10', 'foo.example.com', 'coconut', '10.20.30.40'],
                 /([^.]+)/,
                 '<\1>',
                 'G')
      ).to eql(['<130>.<236>.<254>.<10>', '<foo>.<example>.<com>','<coconut>', '<10>.<20>.<30>.<40>'])
    end
  end
end
