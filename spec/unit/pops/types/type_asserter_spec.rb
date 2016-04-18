require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops::Types
describe 'the type asserter' do
  let!(:asserter) { TypeAsserter }

  context 'when deferring formatting of subject'
  it 'can use an array' do
    expect{ asserter.assert_instance_of(['The %s in the %s', 'gizmo', 'gadget'], PIntegerType::DEFAULT, 'lens') }.to(
    raise_error(TypeAssertionError, 'The gizmo in the gadget had wrong type, expected an Integer value, got String'))
  end

  it 'can use an array obtained from block' do
    expect do
      asserter.assert_instance_of('gizmo', PIntegerType::DEFAULT, 'lens') { |s| ['The %s in the %s', s, 'gadget'] }
    end.to(raise_error(TypeAssertionError, 'The gizmo in the gadget had wrong type, expected an Integer value, got String'))
  end

  it 'can use an subject obtained from zero argument block' do
    expect do
      asserter.assert_instance_of(nil, PIntegerType::DEFAULT, 'lens') { 'The gizmo in the gadget' }
    end.to(raise_error(TypeAssertionError, 'The gizmo in the gadget had wrong type, expected an Integer value, got String'))
  end

  it 'does not produce a string unless the assertion fails' do
    TypeAsserter.expects(:report_type_mismatch).never
    asserter.assert_instance_of(nil, PIntegerType::DEFAULT, 1)
  end

  it 'does not format string unless the assertion fails' do
    fmt_string = 'The %s in the %s'
    fmt_string.expects(:'%').never
    asserter.assert_instance_of([fmt_string, 'gizmo', 'gadget'], PIntegerType::DEFAULT, 1)
  end

  it 'does not call block unless the assertion fails' do
    expect do
      asserter.assert_instance_of(nil, PIntegerType::DEFAULT, 1) { |s| raise Error }
    end.not_to raise_error
  end
end
end
