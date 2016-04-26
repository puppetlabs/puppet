require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'The Object Type' do
  include PuppetSpec::Compiler

  let(:parser) { TypeParser.new }
  let(:pp_parser) { Parser::EvaluatingParser.new }
  let(:loader) { Loader::BaseLoader.new(nil, 'type_parser_unit_test_loader') }
  let(:factory) { TypeFactory }

  def type_object_t(name, body_string)
    object = PObjectType.new(name, pp_parser.parse_string("{#{body_string}}").current.body)
    loader.set_entry(Loader::Loader::TypedName.new(:type, name.downcase), object)
    object
  end

  def parse_object(name, body_string)
    type_object_t(name, body_string)
    parser.parse(name, loader)
  end

  context 'when dealing with attributes' do
    it 'raises an error when the attribute type is not a type' do
      obj = <<-OBJECT
        attributes => {
          a => 23
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /attribute MyObject\[a\] had wrong type, expected a Type value, got Integer/)
    end

    it 'raises an error if the type is missing' do
      obj = <<-OBJECT
        attributes => {
          a => { kind => derived }
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /expected a value for key 'type'/)
    end

    it 'raises an error when value is of incompatible type' do
      obj = <<-OBJECT
        attributes => {
          a => { type => Integer, value => 'three' }
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /attribute MyObject\[a\] value had wrong type, expected an Integer value, got String/)
    end

    it 'raises an error if the kind is invalid' do
      obj = <<-OBJECT
        attributes => {
          a => { type => String, kind => derivd }
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /expected a match for Enum\['constant', 'derived', 'given_or_derived'\], got 'derivd'/)
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

    it 'attribute without defined value responds false to value?' do
      tp = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => Integer
        }
      OBJECT
      attr = tp['a']
      expect(attr.value?).to be_falsey
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
      it 'sets final => true' do
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

  context 'when dealing with functions' do
    it 'raises an error when the function type is a Type[Callable]' do
      obj = <<-OBJECT
        functions => {
          a => String
        }
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError,
        /function MyObject\[a\] had wrong type, expected a Type\[Callable\] value, got Type\[String\]/)
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

    it 'raises an error when the an function overrides an attribute' do
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
    expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError, /object initializer had wrong type, unrecognized key 'attribrutes'/)
  end

  it 'raises an error when attribute contains invalid keys' do
    obj = <<-OBJECT
      attributes => {
        a => { type => Integer, knid => constant }
      }
    OBJECT
    expect { parse_object('MyObject', obj) }.to raise_error(TypeAssertionError, /initializer for attribute MyObject\[a\] had wrong type, unrecognized key 'knid'/)
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

  context 'when producing an i12n_type' do
    it 'produces a struct of all attributes that are not derived or constant' do
      t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer },
          b => { type => Integer, kind => given_or_derived },
          c => { type => Integer, kind => derived },
          d => { type => Integer, kind => constant, value => 4 }
        }
      OBJECT
      expect(t.i12n_type).to eql(factory.struct({
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
      expect(t.i12n_type).to eql(factory.struct({
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
      expect(t1.i12n_type).to eql(factory.struct({ 'a' => factory.integer }))
      expect(t2.i12n_type).to eql(factory.struct({ 'a' => factory.integer, 'b' => factory.integer }))
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
      expect(t1.i12n_type).to eql(factory.struct({ 'a' => factory.integer, 'b' => factory.integer }))
      expect(t2.i12n_type).to eql(factory.struct({ 'a' => factory.integer, factory.optional('b') => factory.integer }))
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
      obj = t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer }
        }
      OBJECT
      expect(obj.to_s).to eql("Object[{name => 'MyObject', attributes => {'a' => Integer}}]")
    end

    it 'produced hash that does not include defaults' do
      obj = t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Integer, value => 23, kind => constant, final => true },
        },
        equality_include_type => true
      OBJECT
      expect(obj.to_s).to eql("Object[{name => 'MyObject', attributes => {'a' => {type => Integer, kind => constant, value => 23}}}]")
    end

    it 'can create an equal copy from produced hash' do
      obj = t = parse_object('MyObject', <<-OBJECT)
        attributes => {
          a => { type => Struct[{x => Integer, y => Integer}], value => {x => 4, y => 9}, kind => constant },
          b => Integer
        },
        functions => {
          x => Callable[MyObject,Integer]
        },
        equality => [b]
      OBJECT
      obj2 = PObjectType.new(obj.i12n_hash)
      expect(obj).to eql(obj2)
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
          "'first_b' => {type => String, kind => constant, value => 'the first constant'}, "+
          "'first_c' => {type => String, final => true, kind => derived}, "+
          "'first_d' => {type => String, kind => given_or_derived}, "+
          "'first_e' => String"+
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
          "'second_b' => {type => String, kind => constant, value => 'the second constant'}, "+
          "'first_e' => {type => Enum['fee', 'foo', 'fum'], final => true, override => true, value => 'fee'}"+
          "}, "+
          "functions => {"+
          "'second_x' => Callable[Integer], "+
          "'second_y' => Callable[String]"+
          "}, "+
          "equality => ['second_a']"+
          "}]"
        ])
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
end
end
end
