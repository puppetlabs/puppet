require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Types
describe 'The Object Type' do
  let(:parser) { TypeParser.new }
  let(:pp_parser) { Puppet::Pops::Parser::EvaluatingParser.new }
  let(:loader) { Puppet::Pops::Loader::BaseLoader.new(nil, 'type_parser_unit_test_loader') }

  def type_object_t(name, body_string)
    TypeFactory.type_alias(name, pp_parser.parse_string("Object[{#{body_string}}]").current)
  end

  def expect_object(name, body_string)
    obj = type_object_t(name, body_string)
    loader.expects(:load).with(:type, name.downcase).at_least_once.returns obj
    obj
  end

  def parse_object(name, body_string)
    expect_object(name, body_string)
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
        /attribute 'a' had wrong type, expected a Type value, got Integer/)
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
        /attribute 'a' value had wrong type, expected an Integer value, got String/)
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

    context 'that are constants' do
      it 'sets final = true' do
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
          /attribute 'a' of kind 'constant' requires a value/)
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
        /function 'a' had wrong type, expected a Type\[Callable\] value, got Type\[String\]/)
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
        "function 'a' conflicts with attribute with the same name")
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
      expect_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp['a'].type).to eql(PIntegerType.new(0,10))
    end

    it 'raises an error when the an attribute overrides a function' do
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "function 'a' overrides inherited attribute")
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "attribute 'a' overrides inherited function")
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "attempt to override attribute 'a' with a type that does not match")
    end

    it 'raises an error when the an attribute overrides a final attribute' do
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "attempt to override final attribute 'a'")
    end

    it 'raises an error when the an overriding attribute is not declared with override => true' do
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "attribute 'a' attempts to override without having override defined")
    end

    it 'raises an error when the an attribute declared with override => true does not override' do
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "expected attribute 'b' to override an inherited attribute")
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

    it 'a single attribute can be declared a name' do
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

    it 'equalty_include_type is true by default' do
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
      expect_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp.equality).to be_nil
      expect(tp.equality_attributes.keys).to eq(['a','b','c','d'])
    end

    it 'will extend equality declared in parent' do
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
      expect_object('MyObject', parent)
      tp = parse_object('MyDerivedObject', obj)
      expect(tp.equality).to be_nil
      expect(tp.equality_attributes.keys).to eq(['a','c','d'])
    end

    it 'will allow that equality contains parent attributes when parent equality does not' do
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
      expect_object('MyObject', parent)
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
      expect_object('MyObject', parent)
      expect { parse_object('MyDerivedObject', obj) }.to raise_error(Puppet::ParseError,
        "equality is referencing attribute 'a' which is already included by parent equality")
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
        "equality is referencing constant attribute 'b'")
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
        "equality is referencing function 'b'")
    end

    it 'raises an error when equality references a non existent attributes' do
      obj = <<-OBJECT
        attributes => {
          a => Integer
        },
        equality => [a,b]
      OBJECT
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::ParseError,
        "equality is referencing non existent attribute 'b'")
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
        'equality_include_type = false cannot be combined with attributes')
    end
  end

  it 'raises an error when initialization hash contains invalid keys' do
    expect_object('MyObject', <<-OBJECT)
      attribrutes => {
        a => Integer
      }
    OBJECT
    expect { parser.parse('MyObject', loader) }.to raise_error(TypeAssertionError, /object initializer had wrong type, extraneous key 'attribrutes'/)
  end

  it 'raises an error when attribute contains invalid keys' do
    expect_object('MyObject', <<-OBJECT)
      attributes => {
        a => { type => Integer, knid => constant }
      }
    OBJECT
    expect { parser.parse('MyObject', loader) }.to raise_error(TypeAssertionError, /initializer for attribute 'a' had wrong type, extraneous key 'knid'/)
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
      expect_object('MyObject', parent)
      t = parse_object('MyDerivedObject', derived)
      members = t.members.values
      expect{ |b| members.each {|m| m.name.tap(&b) }}.to yield_successive_args('c', 'd')
      expect{ |b| members.each {|m| m.type.simple_name.tap(&b) }}.to yield_successive_args('String', 'Boolean')
      members = t.members(true).values
      expect{ |b| members.each {|m| m.name.tap(&b) }}.to yield_successive_args('a', 'b', 'c', 'd')
      expect{ |b| members.each {|m| m.type.simple_name.tap(&b) }}.to(yield_successive_args('Integer', 'Callable', 'String', 'Boolean'))
    end

    it 'will be assignable to its inherited type' do
      p = expect_object('MyObject', parent)
      t = parse_object('MyDerivedObject', derived)
      expect(p).to be_assignable(t)
    end

    it 'will be assignable not consider inherited type to be assignable' do
      p = expect_object('MyObject', parent)
      d = parse_object('MyDerivedObject', derived)
      expect(d).not_to be_assignable(p)
    end

    it 'raises an error when object when circular inheritance is detected' do
      obj = <<-OBJECT
        parent => MyDerivedObject
      OBJECT
      expect_object('MyDerivedObject', derived)
      expect { parse_object('MyObject', obj) }.to raise_error(Puppet::Error, /inherits from itself/)
    end

    context 'that in turn inherits another Object type' do
      let(:derived2) { <<-OBJECT }
        parent => MyDerivedObject,
        attributes => {
          e => String,
          f => Boolean
        }
      OBJECT

      it 'will be assignable to all inherited types' do
        p = expect_object('MyObject', parent)
        d1 = expect_object('MyDerivedObject', derived)
        d2 = parse_object('MyDerivedObject2', derived2)
        expect(p).to be_assignable(d2)
        expect(d1).to be_assignable(d2)
      end

      it 'will not consider any of the inherited types to be assignable' do
        p = expect_object('MyObject', parent)
        d1 = expect_object('MyDerivedObject', derived)
        d2 = parse_object('MyDerivedObject2', derived2)
        expect(d2).not_to be_assignable(p)
        expect(d2).not_to be_assignable(d1)
      end
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
    it 'produced hash use compact form attributes' do
      obj = t = parse_object('MyObject', <<-OBJECT).resolved_type
        attributes => {
          a => { type => Integer }
        }
      OBJECT
      expect(TypeFormatter.string(obj)).to eql('Object[{"attributes" => {"a" => Integer}}]')
    end

    it 'produced hash does not include defaults' do
      obj = t = parse_object('MyObject', <<-OBJECT).resolved_type
        attributes => {
          a => { type => Integer, value => 23, kind => constant, final => true },
        },
        equality_include_type => true
      OBJECT
      expect(TypeFormatter.string(obj)).to eql('Object[{"attributes" => {"a" => {"type" => Integer, "kind" => "constant", "value" => 23}}}]')
    end

    it 'can create an equal copy from produced hash' do
      obj = t = parse_object('MyObject', <<-OBJECT).resolved_type
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
end
end
end
