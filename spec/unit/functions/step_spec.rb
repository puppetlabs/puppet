require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'shared_behaviours/iterative_functions'

describe 'the step method' do
  include PuppetSpec::Compiler

  it 'raises an error when given a type that cannot be iterated' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        3.14.step(1) |$v| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /expects an Iterable value, got Float/)
  end

  it 'raises an error when called with more than two arguments and a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step(1,2) |$v| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /expects 2 arguments, got 3/)
  end

  it 'raises an error when called with more than two arguments and without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step(1,2)
      MANIFEST
    end.to raise_error(Puppet::Error, /expects 2 arguments, got 3/)
  end

  it 'raises an error when called with a block with too many required parameters' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step(1) |$v1, $v2| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /block expects 1 argument, got 2/)
  end

  it 'raises an error when called with a block with too few parameters' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step(1) | | {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /block expects 1 argument, got none/)
  end

  it 'raises an error when called with step == 0' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step(0) |$x| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /'step' expects an Integer\[1, default\] value, got Integer\[0, 0\]/)
  end

  it 'raises an error when step is not an integer' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step('three') |$x| {  }
      MANIFEST
    end.to raise_error(Puppet::Error, /'step' expects an Integer value, got String/)
  end

  it 'does not raise an error when called with a block with too many but optional arguments' do
    expect do
      compile_to_catalog(<<-MANIFEST)
        [1].step(1) |$v1, $v2=extra| {  }
      MANIFEST
    end.to_not raise_error
  end

  it 'returns Undef when called with a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
          assert_type(Undef, [1].step(2) |$x| { $x })
      MANIFEST
    end.not_to raise_error
  end

  it 'returns an Iterable when called without a block' do
    expect do
      compile_to_catalog(<<-MANIFEST)
          assert_type(Iterable, [1].step(2))
      MANIFEST
    end.not_to raise_error
  end

  it 'should produce "times" interval of integer according to step' do
    expect(eval_and_collect_notices('10.step(2) |$x| { notice($x) }')).to eq(['0', '2', '4', '6', '8'])
  end

  it 'should produce interval of Integer[5,20] according to step' do
    expect(eval_and_collect_notices('Integer[5,20].step(4) |$x| { notice($x) }')).to eq(['5', '9', '13', '17'])
  end

  it 'should produce the elements of [a,b,c,d,e,f,g,h] according to step' do
    expect(eval_and_collect_notices('[a,b,c,d,e,f,g,h].step(2) |$x| { notice($x) }')).to eq(%w(a c e g))
  end

  it 'should produce the elements {a=>1,b=>2,c=>3,d=>4,e=>5,f=>6,g=>7,h=>8} according to step' do
    expect(eval_and_collect_notices('{a=>1,b=>2,c=>3,d=>4,e=>5,f=>6,g=>7,h=>8}.step(2) |$t| { notice($t[1]) }')).to eq(%w(1 3 5 7))
  end

  it 'should produce the choices of Enum[a,b,c,d,e,f,g,h] according to step' do
    expect(eval_and_collect_notices('Enum[a,b,c,d,e,f,g,h].step(2) |$x| { notice($x) }')).to eq(%w(a c e g))
  end

  it 'should produce descending interval of Integer[5,20] when chained after a reverse_each' do
    expect(eval_and_collect_notices('Integer[5,20].reverse_each.step(4) |$x| { notice($x) }')).to eq(['20', '16', '12', '8'])
  end
end
