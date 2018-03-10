require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'The Object Type' do
  include PuppetSpec::Compiler

  let(:parser) { TypeParser.singleton }
  let(:pp_parser) { Parser::EvaluatingParser.new }
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:node) { Puppet::Node.new('testnode', :environment => env) }
  let(:loader) { Loaders.find_loader(nil) }
  let(:factory) { TypeFactory }

  before(:each) do
    Puppet.push_context(:loaders => Loaders.new(env))
  end

  after(:each) do
    Puppet.pop_context()
  end

  def type_object_t(name, body_string)
    object = PObjectType.new(name, pp_parser.parse_string("{#{body_string}}").body)
    loader.set_entry(Loader::TypedName.new(:type, name), object)
    object
  end

  def parse_object(name, body_string)
    type_object_t(name, body_string)
    parser.parse(name, loader).resolve(loader)
  end

  context 'when dealing with attributes' do
    it 'raises an error when the attribute type is not a type' do
      obj = <<-OBJECT
        attributes => {
          a => 23
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /attribute MyObject\[a\] has wrong type, expects a Type value, got Integer/)
    end

    it 'raises an error if the type is missing' do
      obj = <<-OBJECT
        attributes => {
          a => { kind => derived }
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /expects a value for key 'type'/)
    end

    it 'raises an error when value is of incompatible type' do
      obj = <<-OBJECT
        attributes => {
          a => { type => Integer, value => 'three' }
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /attribute MyObject\[a\] value has wrong type, expects an Integer value, got String/)
    end

    it 'raises an error if the kind is invalid' do
      obj = <<-OBJECT
        attributes => {
          a => { type => String, kind => derivd }
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /expects a match for Enum\['constant', 'derived', 'given_or_derived', 'reference'\], got 'derivd'/)
    end

    it 'stores value in attribute' do
      tp = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer, value => 3 }
        }
      OBJECT
      attr = tp['a']
      expect(attr).to be_a(PObjectType::PAttribute)
      expect(attr.value).to eql(3)
    end

    it 'attribute with defined value responds true to value?' do
      tp = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer, value => 3 }
        }
      OBJECT
      attr = tp['a']
      expect(attr.value?).to be_truthy
    end

    it 'attribute value can be defined using heredoc?' do
      tp = parse_object('MyObject', <<-OBJECT.unindent)
        attributes => {
          a => { type => String, value => @(END) }
            The value is some
            multiline text
            |-END
        }
      OBJECT
      attr = tp['a']
      expect(attr.value).to eql("The value is some\nmultiline text")
    end

    it 'attribute without defined value responds false to value?' do
      tp = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => Integer
        }
      OBJECT
      attr = tp['a']
      expect(attr.value?).to be_falsey
    end

    it 'attribute without defined value but optional type responds true to value?' do
      tp = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => Optional[Integer]
        }
      OBJECT
      attr = tp['a']
      expect(attr.value?).to be_truthy
      expect(attr.value).to be_nil
    end

    it 'raises an error when value is requested from an attribute that has no value' do
      tp = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => Integer
        }
      OBJECT
      expect { tp['a'].value }.to raise_error(Puppet::Error, 'attribute MyObject[a] has no value')
    end

    context 'that are constants' do
      context 'and declared under key "constants"' do
        it 'sets final => true' do
          tp = parse_object('MyObject', <<-OBJECT)
            constants => {
              a => 3
            }
          OBJECT
          expect(tp['a'].final?).to be_truthy
        end

        it 'sets kind => constant' do
          tp = parse_object('MyObject', <<-OBJECT)
            constants => {
              a => 3
            }
          OBJECT
          expect(tp['a'].constant?).to be_truthy
        end

        it 'infers generic type from value' do
          tp = parse_object('MyObject', <<-OBJECT)
            constants => {
              a => 3
            }
          OBJECT
          expect(tp['a'].type.to_s).to eql('Integer')
        end

        it 'cannot have the same name as an attribute' do
          obj = <<-OBJECT
            constants => {
              a => 3
            },
            attributes => {
              a => Integer
            }
          OBJECT
          expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
            'attribute MyObject[a] is defined as both a constant and an attribute')
        end
      end

      context 'and declared under key "attributes"' do
        it 'sets final => true when declard in attributes' do
          tp = parse_object('MyObject', <<-OBJECT)
            attributes => {
              a => {
                type => Integer,
                kind => constant,
                value => 3
              }
            }
          OBJECT
          expect(tp['a'].final?).to be_truthy
        end

        it 'raises an error when no value is declared' do
          obj = <<-OBJECT
            attributes => {
              a => {
                type => Integer,
                kind => constant
              }
            }
          OBJECT
          expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
            "attribute MyObject[a] of kind 'constant' requires a value")
        end

        it 'raises an error when final => false' do
          obj = <<-OBJECT
            attributes => {
              a => {
                type => Integer,
                kind => constant,
                final => false
              }
            }
          OBJECT
          expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
            "attribute MyObject[a] of kind 'constant' cannot be combined with final => false")
        end
      end
    end
  end

  context 'when dealing with functions' do
    it 'raises an error unless the function type is a Type[Callable]' do
      obj = <<-OBJECT
        functions => {
          a => String
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /function MyObject\[a\] has wrong type, expects a Type\[Callable\] value, got Type\[String\]/)
    end

    it 'raises an error when a function has the same name as an attribute' do
      obj = <<-OBJECT
        attributes => {
          a => Integer
        },
        functions => {
          a => Callable
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
        'function MyObject[a] conflicts with attribute with the same name')
    end
  end

  context 'when dealing with overrides' do
    it 'can redefine inherited member to assignable type' do
      parent = <<-OBJECT
        attributes => {
          a => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          a => { type => Integer[0,10], override => true }
        }
      OBJECT
      parse_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp['a'].type).to eql(PIntegerType.new(0,10))
    end

    it 'can redefine inherited constant to assignable type' do
      parent = <<-OBJECT
        constants => {
          a => 23
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        constants => {
          a => 46
        }
      OBJECT
      tp = parse_object('MyObject', parent)
      td = parse_object('MyDerivedObject', obj)
      expect(tp['a'].value).to eql(23)
      expect(td['a'].value).to eql(46)
    end

    it 'raises an error when an attribute overrides a function' do
      parent = <<-OBJECT
        attributes => {
          a => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        functions => {
          a => { type => Callable, override => true }
        }
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        'function MyDerivedObject[a] attempts to override attribute MyObject[a]')
    end

    it 'raises an error when the a function overrides an attribute' do
      parent = <<-OBJECT
        functions => {
          a => Callable
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          a => { type => Integer, override => true }
        }
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        'attribute MyDerivedObject[a] attempts to override function MyObject[a]')
    end

    it 'raises an error on attempts to redefine inherited member to unassignable type' do
      parent = <<-OBJECT
        attributes => {
          a => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          a => { type => String, override => true }
        }
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        'attribute MyDerivedObject[a] attempts to override attribute MyObject[a] with a type that does not match')
    end

    it 'raises an error when an attribute overrides a final attribute' do
      parent = <<-OBJECT
        attributes => {
          a => { type => Integer, final => true }
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          a => { type => Integer, override => true }
        }
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        'attribute MyDerivedObject[a] attempts to override final attribute MyObject[a]')
    end

    it 'raises an error when an overriding attribute is not declared with override => true' do
      parent = <<-OBJECT
        attributes => {
          a => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          a => Integer
        }
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        'attribute MyDerivedObject[a] attempts to override attribute MyObject[a] without having override => true')
    end

    it 'raises an error when an attribute declared with override => true does not override' do
      parent = <<-OBJECT
        attributes => {
          a => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          b => { type => Integer, override => true }
        }
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "expected attribute MyDerivedObject[b] to override an inherited attribute, but no such attribute was found")
    end
  end

  context 'when dealing with equality' do
    it 'the attributes can be declared as an array of names' do
      obj = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        },
        equality => [a,b]
      OBJECT
      tp = parse_object('MyObject', obj)
      expect(tp.equality).to eq(['a','b'])
      expect(tp.equality_attributes.keys).to eq(['a','b'])
    end

    it 'a single [<name>] can be declared as <name>' do
      obj = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        },
        equality => a
      OBJECT
      tp = parse_object('MyObject', obj)
      expect(tp.equality).to eq(['a'])
    end

    it 'includes all non-constant attributes by default' do
      obj = <<-OBJECT
        attributes => {
          a => Integer,
          b => { type => Integer, kind => constant, value => 3 },
          c => Integer
        }
      OBJECT
      tp = parse_object('MyObject', obj)
      expect(tp.equality).to be_nil
      expect(tp.equality_attributes.keys).to eq(['a','c'])
    end

    it 'equality_include_type is true by default' do
      obj = <<-OBJECT
        attributes => {
          a => Integer
         },
        equality => a
      OBJECT
      expect(parse_object('MyObject', obj).equality_include_type?).to be_truthy
    end

    it 'will allow an empty list of attributes' do
      obj = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        },
        equality => []
      OBJECT
      tp = parse_object('MyObject', obj)
      expect(tp.equality).to be_empty
      expect(tp.equality_attributes).to be_empty
    end

    it 'will extend default equality in parent' do
      parent = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          c => Integer,
          d => Integer
        }
      OBJECT
      parse_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp.equality).to be_nil
      expect(tp.equality_attributes.keys).to eq(['a','b','c','d'])
    end

    it 'extends equality declared in parent' do
      parent = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        },
        equality => a
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          c => Integer,
          d => Integer
        }
      OBJECT
      parse_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp.equality).to be_nil
      expect(tp.equality_attributes.keys).to eq(['a','c','d'])
    end

    it 'parent defined attributes can be included in equality if not already included by a parent' do
      parent = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        },
        equality => a
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          c => Integer,
          d => Integer
        },
        equality => [b,c]
      OBJECT
      parse_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp.equality).to eq(['b','c'])
      expect(tp.equality_attributes.keys).to eq(['a','b','c'])
    end

    it 'raises an error when attempting to extend default equality in parent' do
      parent = <<-OBJECT
        attributes => {
          a => Integer,
          b => Integer
        }
      OBJECT
      obj = <<-OBJECT
        parent => MyObject,
        attributes => {
          c => Integer,
          d => Integer
        },
        equality => a
      OBJECT
      parse_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "MyDerivedObject equality is referencing attribute MyObject[a] which is included in equality of MyObject")
    end

    it 'raises an error when equality references a constant attribute' do
      obj = <<-OBJECT
        attributes => {
          a => Integer,
          b => { type => Integer, kind => constant, value => 3 }
        },
        equality => [a,b]
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
        'MyObject equality is referencing constant attribute MyObject[b]. Reference to constant is not allowed in equality')
    end

    it 'raises an error when equality references a function' do
      obj = <<-OBJECT
        attributes => {
          a => Integer,
        },
        functions => {
          b => Callable
        },
        equality => [a,b]
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
        'MyObject equality is referencing function MyObject[b]. Only attribute references are allowed')
    end

    it 'raises an error when equality references a non existent attributes' do
      obj = <<-OBJECT
        attributes => {
          a => Integer
        },
        equality => [a,b]
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
        "MyObject equality is referencing non existent attribute 'b'")
    end

    it 'raises an error when equality_include_type = false and attributes are provided' do
      obj = <<-OBJECT
        attributes => {
          a => Integer
        },
        equality => a,
        equality_include_type => false
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
        'equality_include_type = false cannot be combined with non empty equality specification')
    end
  end

  it 'raises an error when initialization hash contains invalid keys' do
    obj = <<-OBJECT
      attribrutes => {
        a => Integer
      }
    OBJECT
    expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError, /object initializer has wrong type, unrecognized key 'attribrutes'/)
  end

  it 'raises an error when attribute contains invalid keys' do
    obj = <<-OBJECT
      attributes => {
        a => { type => Integer, knid => constant }
      }
    OBJECT
    expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError, /initializer for attribute MyObject\[a\] has wrong type, unrecognized key 'knid'/)
  end

  context 'when inheriting from a another Object type' do
    let(:parent) { <<-OBJECT }
      attributes => {
        a => Integer
      },
      functions => {
        b => Callable
      }
    OBJECT

    let(:derived) { <<-OBJECT }
      parent => MyObject,
      attributes => {
        c => String,
        d => Boolean
      }
    OBJECT

    it 'includes the inherited type and its members' do
      parse_object('MyObject', parent)
      t = parse_object('MyDerivedObject', derived)
      members = t.members.values
      expect{ |b| members.each {|m| m.name.tap(&b) }}.to yield_successive_args('c', 'd')
      expect{ |b| members.each {|m| m.type.simple_name.tap(&b) }}.to yield_successive_args('String', 'Boolean')
      members = t.members(true).values
      expect{ |b| members.each {|m| m.name.tap(&b) }}.to yield_successive_args('a', 'b', 'c', 'd')
      expect{ |b| members.each {|m| m.type.simple_name.tap(&b) }}.to(yield_successive_args('Integer', 'Callable', 'String', 'Boolean'))
    end

    it 'is assignable to its inherited type' do
      p = parse_object('MyObject', parent)
      t = parse_object('MyDerivedObject', derived)
      expect(p).to be_assignable(t)
    end

    it 'does not consider inherited type to be assignable' do
      p = parse_object('MyObject', parent)
      d = parse_object('MyDerivedObject', derived)
      expect(d).not_to be_assignable(p)
    end

    it 'ruby access operator can retrieve parent member' do
      p = parse_object('MyObject', parent)
      d = parse_object('MyDerivedObject', derived)
      expect(d['b'].container).to equal(p)
    end

    context 'that in turn inherits another Object type' do
      let(:derived2) { <<-OBJECT }
        parent => MyDerivedObject,
        attributes => {
          e => String,
          f => Boolean
        }
      OBJECT

      it 'is assignable to all inherited types' do
        p = parse_object('MyObject', parent)
        d1 = parse_object('MyDerivedObject', derived)
        d2 = parse_object('MyDerivedObject2', derived2)
        expect(p).to be_assignable(d2)
        expect(d1).to be_assignable(d2)
      end

      it 'does not consider any of the inherited types to be assignable' do
        p = parse_object('MyObject', parent)
        d1 = parse_object('MyDerivedObject', derived)
        d2 = parse_object('MyDerivedObject2', derived2)
        expect(d2).not_to be_assignable(p)
        expect(d2).not_to be_assignable(d1)
      end
    end
  end

  context 'when producing an init_hash_type' do
    it 'produces a struct of all attributes that are not derived or constant' do
      t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer },
          b => { type => Integer, kind => given_or_derived },
          c => { type => Integer, kind => derived },
          d => { type => Integer, kind => constant, value => 4 }
        }
      OBJECT
      expect(t.init_hash_type).to eql(factory.struct({
        'a' => factory.integer,
        'b' => factory.integer
      }))
    end

    it 'produces a struct where optional entires are denoted with an optional key' do
      t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer },
          b => { type => Integer, value => 4 }
        }
      OBJECT
      expect(t.init_hash_type).to eql(factory.struct({
        'a' => factory.integer,
        factory.optional('b') => factory.integer
      }))
    end

    it 'produces a struct that includes parameters from parent type' do
      t1 = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer }
        }
      OBJECT
      t2 = parse_object('MyDerivedObject', <<-OBJECT)
        parent => MyObject,
        attributes => {
          b => { type => Integer }
        }
      OBJECT
      expect(t1.init_hash_type).to eql(factory.struct({ 'a' => factory.integer }))
      expect(t2.init_hash_type).to eql(factory.struct({ 'a' => factory.integer, 'b' => factory.integer }))
    end

    it 'produces a struct that reflects overrides made in derived type' do
      t1 = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer },
          b => { type => Integer }
        }
      OBJECT
      t2 = parse_object('MyDerivedObject', <<-OBJECT)
        parent => MyObject,
        attributes => {
          b => { type => Integer, override => true, value => 5 }
        }
      OBJECT
      expect(t1.init_hash_type).to eql(factory.struct({ 'a' => factory.integer, 'b' => factory.integer }))
      expect(t2.init_hash_type).to eql(factory.struct({ 'a' => factory.integer, factory.optional('b') => factory.integer }))
    end
  end

  context 'with attributes and parameters of its own type' do
    it 'resolves an attribute type' do
      t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => MyObject
        }
      OBJECT
      expect(t['a'].type).to equal(t)
    end

    it 'resolves a parameter type' do
      t = parse_object('MyObject', <<-OBJECT)
        functions => {
          a => Callable[MyObject]
        }
      OBJECT
      expect(t['a'].type).to eql(PCallableType.new(PTupleType.new([t])))
    end
  end

  context 'when using the initialization hash' do
    it 'produced hash that contains features using short form (type instead of detailed hash when only type is declared)' do
      obj = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer }
        }
      OBJECT
      expect(obj.to_s).to eql("Object[{name => 'MyObject', attributes => {'a' => Integer}}]")
    end

    it 'produced hash that does not include default for equality_include_type' do
      obj = parse_object('MyObject', <<-OBJECT)
        attributes => { a => Integer },
        equality_include_type => true
      OBJECT
      expect(obj.to_s).to eql("Object[{name => 'MyObject', attributes => {'a' => Integer}}]")
    end

    it 'constants are presented in a separate hash if they use a generic type' do
      obj = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer, value => 23, kind => constant },
        },
      OBJECT
      expect(obj.to_s).to eql("Object[{name => 'MyObject', constants => {'a' => 23}}]")
    end

    it 'constants are not presented in a separate hash unless they use a generic type' do
      obj = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer[0, 30], value => 23, kind => constant },
        },
      OBJECT
      expect(obj.to_s).to eql("Object[{name => 'MyObject', attributes => {'a' => {type => Integer[0, 30], kind => constant, value => 23}}}]")
    end

    it 'can create an equal copy from produced hash' do
      obj = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Struct[{x => Integer, y => Integer}], value => {x => 4, y => 9}, kind => constant },
          b => Integer
        },
        functions => {
          x => Callable[MyObject,Integer]
        },
        equality => [b]
      OBJECT
      obj2 = PObjectType.new(obj._pcore_init_hash)
      expect(obj).to eql(obj2)
    end
  end

  context 'when stringifying created instances' do
    it 'outputs a Puppet constructor using the initializer hash' do
      code = <<-CODE
      type Spec::MyObject = Object[{attributes => { a => Integer }}]
      type Spec::MySecondObject = Object[{parent => Spec::MyObject, attributes => { b => String }}]
      notice(Spec::MySecondObject(42, 'Meaning of life'))
      CODE
      expect(eval_and_collect_notices(code)).to eql(["Spec::MySecondObject({'a' => 42, 'b' => 'Meaning of life'})"])
    end
  end

  context 'when used from Ruby' do
    it 'can create an instance without scope using positional arguments' do
      parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer }
        }
      OBJECT

      t = Puppet::Pops::Types::TypeParser.singleton.parse('MyObject', Puppet::Pops::Loaders.find_loader(nil))
      instance = t.create(32)
      expect(instance.a).to eql(32)
    end

    it 'can create an instance without scope using initialization hash' do
      parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer }
        }
      OBJECT

      t = Puppet::Pops::Types::TypeParser.singleton.parse('MyObject', Puppet::Pops::Loaders.find_loader(nil))
      instance = t.from_hash('a' => 32)
      expect(instance.a).to eql(32)
    end
  end

  context 'when used in Puppet expressions' do
    it 'two anonymous empty objects are equal' do
      code = <<-CODE
      $x = Object[{}]
      $y = Object[{}]
      notice($x == $y)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'two objects where one object inherits another object are different' do
      code = <<-CODE
      type MyFirstObject = Object[{}]
      type MySecondObject = Object[{ parent => MyFirstObject }]
      notice(MyFirstObject == MySecondObject)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['false'])
    end

    it 'two anonymous objects that inherits the same parent are equal' do
      code = <<-CODE
      type MyFirstObject = Object[{}]
      $x = Object[{ parent => MyFirstObject }]
      $y = Object[{ parent => MyFirstObject }]
      notice($x == $y)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'declared Object type is assignable to default Object type' do
      code = <<-CODE
      type MyObject = Object[{ attributes => { a => Integer }}]
      notice(MyObject < Object)
      notice(MyObject <= Object)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true', 'true'])
    end

    it 'default Object type not is assignable to declared Object type' do
      code = <<-CODE
      type MyObject = Object[{ attributes => { a => Integer }}]
      notice(Object < MyObject)
      notice(Object <= MyObject)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['false', 'false'])
    end

    it 'default Object type is assignable to itself' do
      code = <<-CODE
      notice(Object < Object)
      notice(Object <= Object)
      notice(Object > Object)
      notice(Object >= Object)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['false', 'true', 'false', 'true'])
    end

    it 'an object type is an instance of an object type type' do
      code = <<-CODE
      type MyObject = Object[{ attributes => { a => Integer }}]
      notice(MyObject =~ Type[MyObject])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'an object that inherits another object is an instance of the type of its parent' do
      code = <<-CODE
      type MyFirstObject = Object[{}]
      type MySecondObject = Object[{ parent => MyFirstObject }]
      notice(MySecondObject =~ Type[MyFirstObject])
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'a named object is not added to the loader unless a type <name> = <definition> is made' do
      code = <<-CODE
      $x = Object[{ name => 'MyFirstObject' }]
      notice($x == MyFirstObject)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Resource type not found: MyFirstObject/)
    end

    it 'a type alias on a named object overrides the name' do
      code = <<-CODE
      type MyObject = Object[{ name => 'MyFirstObject', attributes => { a => { type => Integer, final => true }}}]
      type MySecondObject = Object[{ parent => MyObject, attributes => { a => { type => Integer[10], override => true }}}]
      notice(MySecondObject =~ Type)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error,
        /attribute MySecondObject\[a\] attempts to override final attribute MyObject\[a\]/)
    end

    it 'a type cannot be created using an unresolved parent' do
      code = <<-CODE
      notice(Object[{ name => 'MyObject', parent => Type('NoneSuch'), attributes => { a => String}}].new('hello'))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error,
        /reference to unresolved type 'NoneSuch'/)
    end

    context 'type alias using bracket-less (implicit Object) form' do
      let(:logs) { [] }
      let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }
      let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }
      let(:node) { Puppet::Node.new('example.com') }
      let(:compiler) { Puppet::Parser::Compiler.new(node) }

      def compile(code)
        Puppet[:code] = code
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) { compiler.compile }
      end

      it 'Object is implicit' do
        compile(<<-CODE)
          type MyObject = { name => 'MyFirstObject', attributes => { a => Integer}}
          notice(MyObject =~ Type)
          notice(MyObject(3))
        CODE
        expect(warnings).to be_empty
        expect(notices).to eql(['true', "MyObject({'a' => 3})"])
      end

      it 'Object can be specified' do
        compile(<<-CODE)
          type MyObject = Object { name => 'MyFirstObject', attributes => { a =>Integer }}
          notice(MyObject =~ Type)
          notice(MyObject(3))
        CODE
        expect(warnings).to be_empty
        expect(notices).to eql(['true', "MyObject({'a' => 3})"])
      end

      it 'parent can be specified before the hash' do
        compile(<<-CODE)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = MyObject { attributes => { b => String }}
          notice(MySecondObject =~ Type)
          notice(MySecondObject < MyObject)
          notice(MyObject('hi'))
          notice(MySecondObject('hello', 'world'))
        CODE
        expect(warnings).to be_empty
        expect(notices).to eql(
          ['true', 'true', "MyObject({'a' => 'hi'})", "MySecondObject({'a' => 'hello', 'b' => 'world'})"])
      end

      it 'parent can be specified in the hash' do
        Puppet[:strict] = 'warning'
        compile(<<-CODE)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = { parent => MyObject, attributes => { b => String }}
          notice(MySecondObject =~ Type)
        CODE
        expect(warnings).to be_empty
        expect(notices).to eql(['true'])
      end

      it 'Object before the hash and parent inside the hash can be combined' do
        Puppet[:strict] = 'warning'
        compile(<<-CODE)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = Object { parent => MyObject, attributes => { b => String }}
          notice(MySecondObject =~ Type)
        CODE
        expect(warnings).to be_empty
        expect(notices).to eql(['true'])
      end

      it 'if strict == warning, a warning is issued when the same is parent specified both before and inside the hash' do
        Puppet[:strict] = 'warning'
        compile(<<-CODE)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = MyObject { parent => MyObject, attributes => { b => String }}
          notice(MySecondObject =~ Type)
        CODE
        expect(notices).to eql(['true'])
        expect(warnings).to eql(["The key 'parent' is declared more than once"])
      end

      it 'if strict == warning, a warning is issued when different parents are specified before and inside the hash. The former overrides the latter' do
        Puppet[:strict] = 'warning'
        compile(<<-CODE)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = MyObject { parent => MyObject, attributes => { b => String }}
          notice(MySecondObject =~ Type)
        CODE
        expect(notices).to eql(['true'])
        expect(warnings).to eql(["The key 'parent' is declared more than once"])
      end

      it 'if strict == error, an error is raised when the same parent is specified both before and inside the hash' do
        Puppet[:strict] = 'error'
        expect { compile(<<-CODE) }.to raise_error(/The key 'parent' is declared more than once/)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = MyObject { parent => MyObject, attributes => { b => String }}
          notice(MySecondObject =~ Type)
        CODE
      end

      it 'if strict == error, an error is raised when different parents are specified before and inside the hash' do
        Puppet[:strict] = 'error'
        expect { compile(<<-CODE) }.to raise_error(/The key 'parent' is declared more than once/)
          type MyObject = { name => 'MyFirstObject', attributes => { a => String }}
          type MySecondObject = MyObject { parent => MyOtherType, attributes => { b => String }}
          notice(MySecondObject =~ Type)
        CODE
      end
    end

    it 'can inherit from an aliased type' do
      code = <<-CODE
      type MyObject = Object[{ name => 'MyFirstObject', attributes => { a => Integer }}]
      type MyObjectAlias = MyObject
      type MySecondObject = Object[{ parent => MyObjectAlias, attributes => { b => String }}]
      notice(MySecondObject < MyObjectAlias)
      notice(MySecondObject < MyObject)
      CODE
      expect(eval_and_collect_notices(code)).to eql(['true', 'true'])
    end

    it 'detects equality duplication when inherited from an aliased type' do
      code = <<-CODE
      type MyObject = Object[{ name => 'MyFirstObject', attributes => { a => Integer }}]
      type MyObjectAlias = MyObject
      type MySecondObject = Object[{ parent => MyObjectAlias, attributes => { b => String }, equality => a}]
      notice(MySecondObject < MyObject)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error,
        /MySecondObject equality is referencing attribute MyObject\[a\] which is included in equality of MyObject/)
    end

    it 'raises an error when object when circular inheritance is detected' do
      code = <<-CODE
      type MyFirstObject = Object[{
        parent => MySecondObject
      }]
      type MySecondObject = Object[{
        parent => MyFirstObject
      }]
      notice(MySecondObject =~ Type[MyFirstObject])
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /inherits from itself/)
    end

    it 'notices the expanded string form expected content' do
      code = <<-CODE
      type MyFirstObject = Object[{
        attributes => {
          first_a => Integer,
          first_b => { type => String, kind => constant, value => 'the first constant' },
          first_c => { type => String, final => true, kind => derived },
          first_d => { type => String, kind => given_or_derived },
          first_e => { type => String }
        },
        functions => {
          first_x => Callable[Integer],
          first_y => Callable[String]
        },
        equality => first_a
      }]
      type MySecondObject = Object[{
        parent => MyFirstObject,
        attributes => {
          second_a => Integer,
          second_b => { type => String, kind => constant, value => 'the second constant' },
          first_e => { type => Enum[foo,fee,fum], final => true, override => true, value => 'fee' }
        },
        functions => {
          second_x => Callable[Integer],
          second_y => Callable[String]
        },
        equality => second_a
      }]
      notice(MyFirstObject)
      notice(MySecondObject)
      CODE
      expect(eval_and_collect_notices(code)).to eql([
        "Object[{"+
          "name => 'MyFirstObject', "+
          "attributes => {"+
          "'first_a' => Integer, "+
          "'first_c' => {type => String, final => true, kind => derived}, "+
          "'first_d' => {type => String, kind => given_or_derived}, "+
          "'first_e' => String"+
          "}, "+
          "constants => {"+
          "'first_b' => 'the first constant'"+
          "}, "+
          "functions => {"+
          "'first_x' => Callable[Integer], "+
          "'first_y' => Callable[String]"+
          "}, "+
          "equality => ['first_a']"+
          "}]",
        "Object[{"+
          "name => 'MySecondObject', "+
          "parent => MyFirstObject, "+
          "attributes => {"+
          "'second_a' => Integer, "+
          "'first_e' => {type => Enum['fee', 'foo', 'fum'], final => true, override => true, value => 'fee'}"+
          "}, "+
          "constants => {"+
          "'second_b' => 'the second constant'"+
          "}, "+
          "functions => {"+
          "'second_x' => Callable[Integer], "+
          "'second_y' => Callable[String]"+
          "}, "+
          "equality => ['second_a']"+
          "}]"
        ])
    end

    context 'object with type parameters' do
      it 'can be declared' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['ok'])
        type MyType = Object[
          type_parameters => {
            p1 => String
          }]
        notice('ok')
        PUPPET
      end

      it 'can be referenced' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(["MyType['hello']"])
        type MyType = Object[
          type_parameters => {
            p1 => String
          }]

        notice(MyType['hello'])
        PUPPET
      end

      it 'leading unset parameters are represented as default in string representation' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(["MyType[default, 'world']"])
        type MyType = Object[
          type_parameters => {
            p1 => String,
            p2 => String,
          }]

        notice(MyType[default, 'world'])
        PUPPET
      end

      it 'trailing unset parameters are skipped in string representation' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(["MyType['my']"])
        type MyType = Object[
          type_parameters => {
            p1 => String,
            p2 => String,
          }]

        notice(MyType['my'])
        PUPPET
      end

      it 'a type with more than 2 type parameters uses named arguments in string representation' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(["MyType[{'p1' => 'my'}]"])
        type MyType = Object[
          type_parameters => {
            p1 => String,
            p2 => String,
            p3 => String,
          }]

        notice(MyType['my'])
        PUPPET
      end

      it 'can be used without parameters' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(["Object[{name => 'MyType', type_parameters => {'p1' => String}}]"])
        type MyType = Object[
          type_parameters => {
            p1 => String
          }]

        notice(MyType)
        PUPPET
      end

      it 'involves type parameter values when testing instance of' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true', 'false', 'true'])
        type MyType = Object[
          type_parameters => {
            p1 => String
          },
          attributes => {
            p1 => String
          }]

        $x = MyType('world')
        notice($x =~ MyType)
        notice($x =~ MyType['hello'])
        notice($x =~ MyType['world'])
        PUPPET
      end

      it 'involves type parameter values when testing assignability' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true', 'false', 'true', 'true', 'false', 'true'])
        type MyType = Object[
          type_parameters => {
            p1 => String
          },
          attributes => {
            p1 => String
          }]

        $x = MyType['world']
        notice($x <= MyType)
        notice($x <= MyType['hello'])
        notice($x <= MyType['world'])

        notice(MyType >= $x)
        notice(MyType['hello'] >= $x)
        notice(MyType['world'] >= $x)
        PUPPET
      end

      it 'parameters can be types' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true', 'true', 'true', 'true', 'false'])
        type MyType = Object[
          type_parameters => {
            p1 => Variant[String,Regexp,Type[Enum],Type[Pattern],Type[NotUndef]],
            p2 => Variant[String,Regexp,Type[Enum],Type[Pattern],Type[NotUndef]],
          },
          attributes => {
            p1 => String,
            p2 => String
          }]
        $x = MyType('good bye', 'cruel world')
        notice($x =~ MyType)
        notice($x =~ MyType[Enum['hello', 'good bye']])
        notice($x =~ MyType[Enum['hello', 'good bye'], Pattern[/world/, /universe/]])
        notice($x =~ MyType[NotUndef, NotUndef])
        notice($x =~ MyType[Enum['hello', 'yo']])
        PUPPET
      end

      it 'parameters can be provided using named arguments' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true', 'false', 'true'])
        type MyType = Object[
          type_parameters => {
            p1 => String,
            p2 => String
          },
          attributes => {
            p1 => String,
            p2 => String
          }]
        $x = MyType('good bye', 'cruel world')
        notice($x =~ MyType)
        notice($x =~ MyType[p1 => 'hello', p2 => 'cruel world'])
        notice($x =~ MyType[p1 => 'good bye', p2 => 'cruel world'])
        PUPPET
      end

      it 'at least one parameter must be given' do
        expect{eval_and_collect_notices(<<-PUPPET, node)}.to raise_error(/The MyType-Type cannot be parameterized using an empty parameter list/)
        type MyType = Object[
          type_parameters => {
            p1 => Variant[String,Regexp,Type[Enum],Type[Pattern]],
          },
          attributes => {
            p1 => String,
          }]
        notice(MyType[default])
        PUPPET
      end

      it 'undef is a valid value for a type parameter' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true', 'false'])
        type MyType = Object[
          type_parameters => {
            p1 => Optional[String],
          },
          attributes => {
            p1 => Optional[String],
          }]
        notice(MyType() =~ MyType[undef])
        notice(MyType('hello') =~ MyType[undef])
        PUPPET
      end

      it 'Type parameters does not mean that type must be parameterized' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true'])
        type MyType = Object[
          type_parameters => {
            p1 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
            p2 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
          },
          attributes => {
            p1 => String,
            p2 => String
          }]
        notice(MyType('hello', 'world') =~ MyType)
        PUPPET
      end

      it 'A parameterized type is assignable to another parameterized type if base type and parameters are assignable' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true'])
        type MyType = Object[
          type_parameters => {
            p1 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
            p2 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
          },
          attributes => {
            p1 => String,
            p2 => String
          }]
        notice(MyType[Pattern[/a/,/b/]] > MyType[Enum['a','b']])
        PUPPET
      end

      it 'Instance is inferred to parameterized type' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['true', 'true', 'true', 'true', 'true'])
        type MyType = Object[
          type_parameters => {
            p1 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
            p2 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
          },
          attributes => {
            p1 => String,
            p2 => String
          }]
        $x = MyType('hello', 'world')
        notice(type($x, generalized) == MyType)
        notice(type($x) < MyType)
        notice(type($x) < MyType['hello'])
        notice(type($x) < MyType[/hello/, /world/])
        notice(type($x) == MyType['hello', 'world'])
        PUPPET
      end

      it 'Attributes of instance of parameterized type can be accessed using function calls' do
        expect(eval_and_collect_notices(<<-PUPPET, node)).to eql(['hello', 'world'])
        type MyType = Object[
          type_parameters => {
            p1 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
            p2 => Variant[Undef,String,Regexp,Type[Enum],Type[Pattern]],
          },
          attributes => {
            p1 => String,
            p2 => String
          }]
        $x = MyType('hello', 'world')
        notice($x.p1)
        notice($x.p2)
        PUPPET
      end
    end
  end

  context "when used with function 'new'" do
    context 'with ordered parameters' do
      it 'creates an instance with initialized attributes' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => Integer,
            b => String
          }
        }]
        $obj = MyFirstObject.new(3, 'hi')
        notice($obj.a)
        notice($obj.b)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['3', 'hi'])
      end

      it 'creates an instance with default attribute values' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, value => 'the default' }
          }
        }]
        $obj = MyFirstObject.new
        notice($obj.a)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['the default'])
      end

      it 'creates an instance with constant attributes' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, kind => constant, value => 'the constant' }
          }
        }]
        $obj = MyFirstObject.new
        notice($obj.a)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['the constant'])
      end

      it 'creates an instance with overridden attribute defaults' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, value => 'the default' }
          }
        }]
        $obj = MyFirstObject.new('not default')
        notice($obj.a)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['not default'])
      end

      it 'fails on an attempt to provide a constant attribute value' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, kind => constant, value => 'the constant' }
          }
        }]
        $obj = MyFirstObject.new('not constant')
        notice($obj.a)
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects no arguments/)
      end

      it 'fails when a required key is missing' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => String
          }
        }]
        $obj = MyFirstObject.new
        notice($obj.a)
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects 1 argument, got none/)
      end

      it 'creates a derived instance with initialized attributes' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => Integer,
            b => { type => String, kind => constant, value => 'the first constant' },
            c => String
          }
        }]
        type MySecondObject = Object[{
          parent => MyFirstObject,
          attributes => {
            d => { type => Integer, value => 34 }
          }
        }]
        $obj = MySecondObject.new(3, 'hi')
        notice($obj.a)
        notice($obj.b)
        notice($obj.c)
        notice($obj.d)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['3', 'the first constant', 'hi', '34'])
      end
    end

    context 'with named parameters' do
      it 'creates an instance with initialized attributes' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => Integer,
            b => String
          }
        }]
        $obj = MyFirstObject.new({b => 'hi', a => 3})
        notice($obj.a)
        notice($obj.b)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['3', 'hi'])
      end

      it 'creates an instance with default attribute values' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, value => 'the default' }
          }
        }]
        $obj = MyFirstObject.new({})
        notice($obj.a)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['the default'])
      end

      it 'creates an instance with constant attributes' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, kind => constant, value => 'the constant' }
          }
        }]
        $obj = MyFirstObject.new({})
        notice($obj.a)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['the constant'])
      end

      it 'creates an instance with overridden attribute defaults' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, value => 'the default' }
          }
        }]
        $obj = MyFirstObject.new({a => 'not default'})
        notice($obj.a)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['not default'])
      end

      it 'fails on an attempt to provide a constant attribute value' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => { type => String, kind => constant, value => 'the constant' }
          }
        }]
        $obj = MyFirstObject.new({a => 'not constant'})
        notice($obj.a)
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /unrecognized key 'a'/)
      end

      it 'fails when a required key is missing' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => String
          }
        }]
        $obj = MyFirstObject.new({})
        notice($obj.a)
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /expects size to be 1, got 0/)
      end

      it 'creates a derived instance with initialized attributes' do
        code = <<-CODE
        type MyFirstObject = Object[{
          attributes => {
            a => Integer,
            b => { type => String, kind => constant, value => 'the first constant' },
            c => String
          }
        }]
        type MySecondObject = Object[{
          parent => MyFirstObject,
          attributes => {
            d => { type => Integer, value => 34 }
          }
        }]
        $obj = MySecondObject.new({c => 'hi', a => 3})
        notice($obj.a)
        notice($obj.b)
        notice($obj.c)
        notice($obj.d)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['3', 'the first constant', 'hi', '34'])
      end
    end
  end

  context 'is assigned to all PAnyType classes such that' do
    include_context 'types_setup'

    def find_parent(tc, parent_name)
      p = tc._pcore_type
      while p.is_a?(PObjectType) && p.name != parent_name
        p = p.parent
      end
      expect(p).to be_a(PObjectType), "did not find #{parent_name} in parent chain of #{tc.name}"
      p
    end

    it 'the class has a _pcore_type method' do
      all_types.each do |tc|
        expect(tc).to respond_to(:_pcore_type).with(0).arguments
      end
    end

    it 'the _pcore_type method returns a PObjectType instance' do
      all_types.each do |tc|
        expect(tc._pcore_type).to be_a(PObjectType)
      end
    end

    it 'the instance returned by _pcore_type is a descendant from Pcore::AnyType' do
      all_types.each { |tc| expect(find_parent(tc, 'Pcore::AnyType').name).to eq('Pcore::AnyType') }
    end

    it 'PScalarType classes _pcore_type returns a descendant from Pcore::ScalarType' do
      scalar_types.each { |tc| expect(find_parent(tc, 'Pcore::ScalarType').name).to eq('Pcore::ScalarType') }
    end

    it 'PNumericType classes _pcore_type returns a descendant from Pcore::NumberType' do
      numeric_types.each { |tc| expect(find_parent(tc, 'Pcore::NumericType').name).to eq('Pcore::NumericType') }
    end

    it 'PCollectionType classes _pcore_type returns a descendant from Pcore::CollectionType' do
      coll_descendants = collection_types - [PTupleType, PStructType]
      coll_descendants.each { |tc| expect(find_parent(tc, 'Pcore::CollectionType').name).to eq('Pcore::CollectionType') }
    end
  end

  context 'when dealing with annotations' do
    let(:annotation) { <<-PUPPET }
      type MyAdapter = Object[{
        parent => Annotation,
        attributes => {
          id => Integer,
          value => String[1]
        }
      }]
    PUPPET

    it 'the Annotation type can be used as parent' do
      code = <<-PUPPET
        #{annotation}
        notice(MyAdapter < Annotation)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['true'])
    end

    it 'an annotation can be added to an Object type' do
      code = <<-PUPPET
        #{annotation}
        type MyObject = Object[{
          annotations => {
            MyAdapter => { 'id' => 2, 'value' => 'annotation value' }
          }
        }]
        notice(MyObject)
      PUPPET
      expect(eval_and_collect_notices(code)).to eql([
        "Object[{annotations => {MyAdapter => {'id' => 2, 'value' => 'annotation value'}}, name => 'MyObject'}]"])
    end

    it 'other types can not be used as annotations' do
      code = <<-PUPPET
        type NotAnAnnotation = Object[{}]
        type MyObject = Object[{
          annotations => {
            NotAnAnnotation => {}
          }
        }]
        notice(MyObject)
      PUPPET
      expect{eval_and_collect_notices(code)}.to raise_error(/entry 'annotations' expects a value of type Undef or Hash/)
    end
  end
end
end
end
