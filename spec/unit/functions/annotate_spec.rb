require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

describe 'the annotate function' do
  include PuppetSpec::Compiler

  let(:annotation) { <<-PUPPET }
    type MyAdapter = Object[{
      parent => Annotation,
      attributes => {
        id => Integer,
        value => String[1]
      }
    }]
  PUPPET

  let(:annotation2) { <<-PUPPET }
    type MyAdapter2 = Object[{
      parent => Annotation,
      attributes => {
        id => Integer,
        value => String[1]
      }
    }]
  PUPPET

  context 'with object and hash arguments' do
    it 'creates new annotation on object' do
      code = <<-PUPPET
        #{annotation}
        type MyObject = Object[{
        }]
        $my_object = MyObject({})
        MyAdapter.annotate($my_object, { 'id' => 2, 'value' => 'annotation value' })
        notice(MyAdapter.annotate($my_object).value)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['annotation value'])
    end

    it 'forces creation of new annotation' do
      code = <<-PUPPET
      #{annotation}
      type MyObject = Object[{
      }]
      $my_object = MyObject({})
      MyAdapter.annotate($my_object, { 'id' => 2, 'value' => 'annotation value' })
      notice(MyAdapter.annotate($my_object).value)
      MyAdapter.annotate($my_object, { 'id' => 2, 'value' => 'annotation value 2' })
      notice(MyAdapter.annotate($my_object).value)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['annotation value', 'annotation value 2'])
    end
  end

  context 'with object and block arguments' do
    it 'creates new annotation on object' do
      code = <<-PUPPET
        #{annotation}
        type MyObject = Object[{
        }]
        $my_object = MyObject({})
        MyAdapter.annotate($my_object) || { { 'id' => 2, 'value' => 'annotation value' } }
        notice(MyAdapter.annotate($my_object).value)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['annotation value'])
    end

    it 'does not recreate annotation' do
      code = <<-PUPPET
      #{annotation}
      type MyObject = Object[{
      }]
      $my_object = MyObject({})
      MyAdapter.annotate($my_object) || {
        notice('should call this');
        { 'id' => 2, 'value' => 'annotation value' }
      }
      MyAdapter.annotate($my_object) || {
        notice('should not call this');
        { 'id' => 2, 'value' => 'annotation value 2' }
      }
      notice(MyAdapter.annotate($my_object).value)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['should call this', 'annotation value'])
    end
  end

  it "with object and 'clear' arguments, clears and returns annotation" do
    code = <<-PUPPET
      #{annotation}
      type MyObject = Object[{
      }]
      $my_object = MyObject({})
      MyAdapter.annotate($my_object, { 'id' => 2, 'value' => 'annotation value' })
      notice(MyAdapter.annotate($my_object, clear).value)
      notice(MyAdapter.annotate($my_object) == undef)
    PUPPET
    expect(eval_and_collect_notices(code)).to eql(['annotation value', 'true'])
  end

  context 'when object is an annotated Type' do
    it 'finds annotation declared in the type' do
      code = <<-PUPPET
        #{annotation}
        type MyObject = Object[{
          annotations => {
            MyAdapter => { 'id' => 2, 'value' => 'annotation value' }
          }
        }]
        notice(MyAdapter.annotate(MyObject).value)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['annotation value'])
    end

    it 'fails attempts to clear a declared annotation' do
      code = <<-PUPPET
        #{annotation}
        type MyObject = Object[{
          annotations => {
            MyAdapter => { 'id' => 2, 'value' => 'annotation value' }
          }
        }]
        notice(MyAdapter.annotate(MyObject).value)
        notice(MyAdapter.annotate(MyObject, clear).value)
      PUPPET
      expect { eval_and_collect_notices(code) }.to raise_error(/attempt to clear MyAdapter annotation declared on MyObject/)
    end

    it 'fails attempts to redefine a declared annotation' do
      code = <<-PUPPET
        #{annotation}
        type MyObject = Object[{
          annotations => {
            MyAdapter => { 'id' => 2, 'value' => 'annotation value' }
          }
        }]
        notice(MyAdapter.annotate(MyObject).value)
        notice(MyAdapter.annotate(MyObject, { 'id' => 3, 'value' => 'some other value' }).value)
      PUPPET
      expect { eval_and_collect_notices(code) }.to raise_error(/attempt to redefine MyAdapter annotation declared on MyObject/)
    end

    it 'allows annotation that are not declared in the type' do
      code = <<-PUPPET
        #{annotation}
        #{annotation2}
        type MyObject = Object[{
          annotations => {
            MyAdapter => { 'id' => 2, 'value' => 'annotation value' }
          }
        }]
        notice(MyAdapter.annotate(MyObject).value)
        notice(MyAdapter2.annotate(MyObject, { 'id' => 3, 'value' => 'some other value' }).value)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['annotation value', 'some other value'])
    end
  end

  it 'used on Pcore, can add multiple annotations an object' do
    code = <<-PUPPET
      #{annotation}
      #{annotation2}
      type MyObject = Object[{
      }]
      $my_object = Pcore.annotate(MyObject({}), {
        MyAdapter => { 'id' => 2, 'value' => 'annotation value' },
        MyAdapter2 => { 'id' => 3, 'value' => 'second annotation value' }
      })
      notice(MyAdapter.annotate($my_object).value)
      notice(MyAdapter2.annotate($my_object).value)
    PUPPET
    expect(eval_and_collect_notices(code)).to eql(['annotation value', 'second annotation value'])
  end
end
