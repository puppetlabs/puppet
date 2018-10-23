require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the eval function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'evaluates a string with puppet logic' do
    notices = eval_and_collect_notices(<<-PUPPET)
      $x = '1+2'
      notice(['result is ', eval($x)].join)
    PUPPET
    expect(notices).to include('result is 3')
  end

  it 'sets variables in a local scope from a hash' do
    notices = eval_and_collect_notices(<<-PUPPET)
      $x = 'shadowed value'
      notice(['result is ', eval('$x', {'x' => 42})].join)
    PUPPET
    expect(notices).to include('result is 42')
  end

  it 'variables set in the evaluated string are set in a local scope' do
    notices = eval_and_collect_notices(<<-PUPPET)
        $y = '$x = 42; $x'
        notice(['result is ', eval($y)].join)
        notice(['defined is ', defined('$x')].join)
        PUPPET
     expect(notices).to include('result is 42')
     expect(notices).to include('defined is false')
  end

  it 'definitions in evaluated string are made available inside and after the eval' do
    notices = eval_and_collect_notices(<<-PUPPET)
        $y = 'function foo(Integer $x) { $x * 2 } foo(30)'
        notice(['inside result is ', eval($y)].join)
        notice(['after result is ', foo(10)].join)
        PUPPET
     expect(notices).to include('inside result is 60')
     expect(notices).to include('after result is 20')
  end

end
