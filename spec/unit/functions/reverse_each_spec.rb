require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the reverse_each function' do
  include PuppetSpec::Compiler

  it 'raises an error when given a type that cannot be iterated' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        3.14.reverse_each |$v| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /expects an Iterable value, got Float/)
  end

  it 'raises an error when called with more than one argument and without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].reverse_each(1)
      MANIFEST
    end.to raise_error(Puppet::Error, /expects 1 argument, got 2/)
  end

  it 'raises an error when called with more than one argument and a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].reverse_each(1) |$v| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /expects 1 argument, got 2/)
  end

  it 'raises an error when called with a block with too many required parameters' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].reverse_each() |$v1, $v2| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /block expects 1 argument, got 2/)
  end

  it 'raises an error when called with a block with too few parameters' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].reverse_each() | | {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /block expects 1 argument, got none/)
  end

  it 'does not raise an error when called with a block with too many but optional arguments' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].reverse_each() |$v1, $v2=extra| {  }
      MANIFEST
    end.to_not raise_error
  end

  it 'returns an Undef when called with a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
            assert_type(Undef, [1].reverse_each |$x| { $x })
      MANIFEST
    end.not_to raise_error
  end

  it 'returns an Iterable when called without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
            assert_type(Iterable, [1].reverse_each)
      MANIFEST
    end.not_to raise_error
  end

  it 'should produce "times" interval of integer in reverse' do
    expect(eval_and_collect_notices('5.reverse_each |$x| { notice($x) }')).to eq(['4', '3', '2', '1', '0'])
  end

  it 'should produce range Integer[5,8] in reverse' do
    expect(eval_and_collect_notices('Integer[5,8].reverse_each |$x| { notice($x) }')).to eq(['8', '7', '6', '5'])
  end

  it 'should produce the choices of [first,second,third] in reverse' do
    expect(eval_and_collect_notices('[first,second,third].reverse_each |$x| { notice($x) }')).to eq(%w(third second first))
  end

  it 'should produce the choices of {first => 1,second => 2,third => 3} in reverse' do
    expect(eval_and_collect_notices('{first => 1,second => 2,third => 3}.reverse_each |$t| { notice($t[0]) }')).to eq(%w(third second first))
  end

  it 'should produce the choices of Enum[first,second,third] in reverse' do
    expect(eval_and_collect_notices('Enum[first,second,third].reverse_each |$x| { notice($x) }')).to eq(%w(third second first))
  end

  it 'should produce nth element in reverse of range Integer[5,20] when chained after a step' do
    expect(eval_and_collect_notices('Integer[5,20].step(4).reverse_each |$x| { notice($x) }')
    ).to eq(['17', '13', '9', '5'])
  end

  it 'should produce nth element in reverse of times 5 when chained after a step' do
    expect(eval_and_collect_notices('5.step(2).reverse_each |$x| { notice($x) }')).to eq(['4', '2', '0'])
  end

  it 'should produce nth element in reverse of range Integer[5,20] when chained after a step' do
    expect(eval_and_collect_notices(
      '[5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20].step(4).reverse_each |$x| { notice($x) }')
    ).to eq(['17', '13', '9', '5'])
  end
end
