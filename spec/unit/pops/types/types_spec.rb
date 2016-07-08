require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'Puppet Type System' do
  include PuppetSpec::Compiler

  let(:tf) { TypeFactory }
  context 'Integer type' do
    let!(:a) { tf.range(10, 20) }
    let!(:b) { tf.range(18, 28) }
    let!(:c) { tf.range( 2, 12) }
    let!(:d) { tf.range(12, 18) }
    let!(:e) { tf.range( 8, 22) }
    let!(:f) { tf.range( 8,  9) }
    let!(:g) { tf.range(21, 22) }
    let!(:h) { tf.range(30, 31) }
    let!(:i) { tf.float_range(1.0, 30.0) }
    let!(:j) { tf.float_range(1.0, 9.0) }

    context 'when testing if ranges intersect' do
      it 'detects an intersection when self is before its argument' do
        expect(a.intersect?(b)).to be_truthy
      end

      it 'detects an intersection when self is after its argument' do
        expect(a.intersect?(c)).to be_truthy
      end

      it 'detects an intersection when self covers its argument' do
        expect(a.intersect?(d)).to be_truthy
      end

      it 'detects an intersection when self equals its argument' do
        expect(a.intersect?(a)).to be_truthy
      end

      it 'detects an intersection when self is covered by its argument' do
        expect(a.intersect?(e)).to be_truthy
      end

      it 'does not consider an adjacent range to be intersecting' do
        [f, g].each {|x| expect(a.intersect?(x)).to be_falsey }
      end

      it 'does not consider an range that is apart to be intersecting' do
        expect(a.intersect?(h)).to be_falsey
      end

      it 'does not consider an overlapping float range to be intersecting' do
        expect(a.intersect?(i)).to be_falsey
      end
    end

    context 'when testing if ranges are adjacent' do
      it 'detects an adjacent type when self is after its argument' do
        expect(a.adjacent?(f)).to be_truthy
      end

      it 'detects an adjacent type when self is before its argument' do
        expect(a.adjacent?(g)).to be_truthy
      end

      it 'does not consider overlapping types to be adjacent' do
        [a, b, c, d, e].each { |x| expect(a.adjacent?(x)).to be_falsey }
      end

      it 'does not consider an range that is apart to be adjacent' do
        expect(a.adjacent?(h)).to be_falsey
      end

      it 'does not consider an adjacent float range to be adjancent' do
        expect(a.adjacent?(j)).to be_falsey
      end
    end

    context 'when merging ranges' do
      it 'will merge intersecting ranges' do
        expect(a.merge(b)).to eq(tf.range(10, 28))
      end

      it 'will merge adjacent ranges' do
        expect(a.merge(g)).to eq(tf.range(10, 22))
      end

      it 'will not merge ranges that are apart' do
        expect(a.merge(h)).to be_nil
      end

      it 'will not merge overlapping float ranges' do
        expect(a.merge(i)).to be_nil
      end

      it 'will not merge adjacent float ranges' do
        expect(a.merge(j)).to be_nil
      end
    end
  end

  context 'Float type' do
    let!(:a) { tf.float_range(10.0, 20.0) }
    let!(:b) { tf.float_range(18.0, 28.0) }
    let!(:c) { tf.float_range( 2.0, 12.0) }
    let!(:d) { tf.float_range(12.0, 18.0) }
    let!(:e) { tf.float_range( 8.0, 22.0) }
    let!(:f) { tf.float_range(30.0, 31.0) }
    let!(:g) { tf.range(1, 30) }

    context 'when testing if ranges intersect' do
      it 'detects an intersection when self is before its argument' do
        expect(a.intersect?(b)).to be_truthy
      end

      it 'detects an intersection when self is after its argument' do
        expect(a.intersect?(c)).to be_truthy
      end

      it 'detects an intersection when self covers its argument' do
        expect(a.intersect?(d)).to be_truthy
      end

      it 'detects an intersection when self equals its argument' do
        expect(a.intersect?(a)).to be_truthy
      end

      it 'detects an intersection when self is covered by its argument' do
        expect(a.intersect?(e)).to be_truthy
      end

      it 'does not consider an range that is apart to be intersecting' do
        expect(a.intersect?(f)).to be_falsey
      end

      it 'does not consider an overlapping integer range to be intersecting' do
        expect(a.intersect?(g)).to be_falsey
      end
    end

    context 'when merging ranges' do
      it 'will merge intersecting ranges' do
        expect(a.merge(b)).to eq(tf.float_range(10.0, 28.0))
      end

      it 'will not merge ranges that are apart' do
        expect(a.merge(f)).to be_nil
      end

      it 'will not merge overlapping integer ranges' do
        expect(a.merge(g)).to be_nil
      end
    end
  end

  context 'Enum type' do
    it 'sorts its entries' do
      code = <<-CODE
        Enum[c,b,a].each |$e| { notice $e }
      CODE
      expect(eval_and_collect_notices(code)).to eq(['a', 'b', 'c'])
    end

    it 'makes entries unique' do
      code = <<-CODE
        Enum[a,b,c,b,a].each |$e| { notice $e }
      CODE
      expect(eval_and_collect_notices(code)).to eq(['a', 'b', 'c'])
    end
  end

  context 'Iterable type' do
    it 'can be parameterized with element type' do
      code = <<-CODE
      function foo(Iterable[String] $x) {
        $x.each |$e| {
          notice $e
        }
      }
      foo([bar, baz, cake])
      CODE
      expect(eval_and_collect_notices(code)).to eq(['bar', 'baz', 'cake'])
    end
  end

  context 'Iterator type' do
    let!(:iterint) { tf.iterator(tf.integer) }

    context 'when testing instance?' do
      it 'will consider an iterable on an integer is an instance of Iterator[Integer]' do
        expect(iterint.instance?(Iterable.on(3))).to be_truthy
      end

      it 'will consider an iterable on string to be an instance of Iterator[Integer]' do
        expect(iterint.instance?(Iterable.on('string'))).to be_falsey
      end
    end

    context 'when testing assignable?' do
      it 'will consider an iterator with an assignable type as assignable' do
        expect(tf.iterator(tf.numeric).assignable?(iterint)).to be_truthy
      end

      it 'will not consider an iterator with a non assignable type as assignable' do
        expect(tf.iterator(tf.string).assignable?(iterint)).to be_falsey
      end
    end

    context 'when asked for an iterable type' do
      it 'the default iterator type returns the default iterable type' do
        expect(PIteratorType::DEFAULT.iterable_type).to be(PIterableType::DEFAULT)
      end

      it 'a typed iterator type returns the an equally typed iterable type' do
        expect(iterint.iterable_type).to eq(tf.iterable(tf.integer))
      end
    end

    it 'can be parameterized with an element type' do
      code = <<-CODE
      function foo(Iterator[String] $x) {
        $x.each |$e| {
          notice $e
        }
      }
      foo([bar, baz, cake].reverse_each)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['cake', 'baz', 'bar'])
    end
  end

  context 'Collection type' do
    it 'can be parameterized with a range' do
      code = <<-CODE
      notice(Collection[5, default] == Collection[5])
      notice(Collection[5, 5] > Tuple[Integer, 0, 10])
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true', 'false'])
    end
  end

  context 'Struct type' do
    context 'can be used as key in hash' do
      it 'compacts optional in optional in optional to just optional' do
        key1 = tf.struct({'foo' => tf.string})
        key2 = tf.struct({'foo' => tf.string})
        expect({key1 => 'hi'}[key2]).to eq('hi')
      end
    end
  end

  context 'Optional type' do
    let!(:overlapping_ints) { tf.variant(tf.range(10, 20), tf.range(18, 28)) }
    let!(:optoptopt) { tf.optional(tf.optional(tf.optional(overlapping_ints))) }
    let!(:optnu) { tf.optional(tf.not_undef(overlapping_ints)) }

    context 'when normalizing' do
      it 'compacts optional in optional in optional to just optional' do
        expect(optoptopt.normalize).to eq(tf.optional(tf.range(10, 28)))
      end
    end

    it 'compacts NotUndef in Optional to just Optional' do
      expect(optnu.normalize).to eq(tf.optional(tf.range(10, 28)))
    end
  end

  context 'NotUndef type' do
    let!(:nununu) { tf.not_undef(tf.not_undef(tf.not_undef(tf.any))) }
    let!(:nuopt) { tf.not_undef(tf.optional(tf.any)) }
    let!(:nuoptint) { tf.not_undef(tf.optional(tf.integer)) }

    context 'when normalizing' do
      it 'compacts NotUndef in NotUndef in NotUndef to just NotUndef' do
        expect(nununu.normalize).to eq(tf.not_undef(tf.any))
      end

      it 'compacts Optional in NotUndef to just NotUndef' do
        expect(nuopt.normalize).to eq(tf.not_undef(tf.any))
      end

      it 'compacts NotUndef[Optional[Integer]] in NotUndef to just Integer' do
        expect(nuoptint.normalize).to eq(tf.integer)
      end
    end
  end

  context 'Variant type' do
    let!(:overlapping_ints) { tf.variant(tf.range(10, 20), tf.range(18, 28)) }
    let!(:adjacent_ints) { tf.variant(tf.range(10, 20), tf.range(8, 9)) }
    let!(:mix_ints) { tf.variant(overlapping_ints, adjacent_ints) }
    let!(:overlapping_floats) { tf.variant(tf.float_range(10.0, 20.0), tf.float_range(18.0, 28.0)) }
    let!(:enums) { tf.variant(tf.enum('a', 'b'), tf.enum('b', 'c')) }
    let!(:patterns) { tf.variant(tf.pattern('a', 'b'), tf.pattern('b', 'c')) }
    let!(:with_undef) { tf.variant(tf.undef, tf.range(1,10)) }
    let!(:all_optional) { tf.variant(tf.optional(tf.range(1,10)), tf.optional(tf.range(11,20))) }
    let!(:groups) { tf.variant(mix_ints, overlapping_floats, enums, patterns, with_undef, all_optional) }

    context 'when normalizing contained types that' do
      it 'are overlapping ints, the result is a range' do
        expect(overlapping_ints.normalize).to eq(tf.range(10, 28))
      end

      it 'are adjacent ints, the result is a range' do
        expect(adjacent_ints.normalize).to eq(tf.range(8, 20))
      end

      it 'are mixed variants with adjacent and overlapping ints, the result is a range' do
        expect(mix_ints.normalize).to eq(tf.range(8, 28))
      end

      it 'are overlapping floats, the result is a float range' do
        expect(overlapping_floats.normalize).to eq(tf.float_range(10.0, 28.0))
      end

      it 'are enums, the result is an enum' do
        expect(enums.normalize).to eq(tf.enum('a', 'b', 'c'))
      end

      it 'are patterns, the result is a pattern' do
        expect(patterns.normalize).to eq(tf.pattern('a', 'b', 'c'))
      end

      it 'contains an Undef, the result is Optional' do
        expect(with_undef.normalize).to eq(tf.optional(tf.range(1,10)))
      end

      it 'are all Optional, the result is an Optional with normalized type' do
        expect(all_optional.normalize).to eq(tf.optional(tf.range(1,20)))
      end

      it 'can be normalized in groups, the result is a Variant containing the resulting normalizations' do
        expect(groups.normalize).to eq(tf.variant(
          tf.range(8, 28),
          tf.float_range(10.0, 28.0),
          tf.enum('a', 'b', 'c'),
          tf.pattern('a', 'b', 'c'),
          tf.optional(tf.range(1,20)))
        )
      end
    end

    context 'when generalizing' do
      it 'will generalize and compact contained types' do
        expect(tf.variant(tf.string(tf.range(3,3)), tf.string(tf.range(5,5))).generalize).to eq(tf.variant(tf.string))
      end
    end
  end

  context 'Runtime type' do
    it 'can be created with a runtime and a runtime type name' do
      expect(tf.runtime('ruby', 'Hash').to_s).to eq("Runtime[ruby, 'Hash']")
    end

    it 'can be created with a runtime and, puppet name pattern, and runtime replacement' do
      expect(tf.runtime('ruby', [/^MyPackage::(.*)$/, 'MyModule::\1']).to_s).to eq("Runtime[ruby, [/^MyPackage::(.*)$/, \"MyModule::\\\\1\"]]")
    end

    it 'will map a Puppet name to a runtime type' do
      t = tf.runtime('ruby', [/^MyPackage::(.*)$/, 'MyModule::\1'])
      expect(t.from_puppet_name('MyPackage::MyType').to_s).to eq("Runtime[ruby, 'MyModule::MyType']")
    end
  end

  context 'Type aliases' do
    it 'will resolve nested objects using self recursion' do
      code = <<-CODE
      type Tree = Hash[String,Variant[String,Tree]]
      notice({a => {b => {c => d}}} =~ Tree)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true'])
    end

    it 'will find mismatches using self recursion' do
      code = <<-CODE
      type Tree = Hash[String,Variant[String,Tree]]
      notice({a => {b => {c => 1}}} =~ Tree)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['false'])
    end

    it 'will not allow an alias chain to only contain aliases' do
      code = <<-CODE
      type Foo = Bar
      type Fee = Foo
      type Bar = Fee
      notice(0 =~ Bar)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Type alias 'Foo' cannot be resolved to a real type/)
    end

    it 'will not allow an alias chain that contains nothing but aliases and variants' do
      code = <<-CODE
      type Foo = Bar
      type Fee = Foo
      type Bar = Variant[Fee,Foo]
      notice(0 =~ Bar)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Type alias 'Foo' cannot be resolved to a real type/)
    end

    it 'will not allow an alias to directly reference itself' do
      code = <<-CODE
      type Foo = Foo
      notice(0 =~ Foo)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Type alias 'Foo' cannot be resolved to a real type/)
    end

    it 'will allow an alias to directly reference itself in a variant with other types' do
      code = <<-CODE
      type Foo = Variant[Foo,String]
      notice(a =~ Foo)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true'])
    end

    it 'will allow an alias where a variant references an alias with a variant that references itself' do
      code = <<-CODE
      type X = Variant[Y, Integer]
      type Y = Variant[X, String]

      notice(X >= X)
      notice(X >= Y)
      notice(Y >= X)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true','true','true'])
    end

    it 'will detect a mismatch in an alias that directly references itself in a variant with other types' do
      code = <<-CODE
      type Foo = Variant[Foo,String]
      notice(3 =~ Foo)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['false'])
    end

    it 'will normalize a Variant containing a self reference so that the self reference is removed' do
      code = <<-CODE
      type Foo = Variant[Foo,String,Integer]
      assert_type(Foo, /x/)
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/expected a value of type String or Integer, got Regexp/)
    end

    it 'will handle a scalar correctly in combinations of nested aliased variants' do
      code = <<-CODE
      type Bar = Variant[Foo,Integer]
      type Foo = Variant[Bar,String]
      notice(a =~ Foo)
      notice(1 =~ Foo)
      notice(/x/ =~ Foo)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true', 'true', 'false'])
    end

    it 'will handle a non scalar correctly in combinations of nested aliased array with nested variants' do
      code = <<-CODE
      type Bar = Variant[Foo,Integer]
      type Foo = Array[Variant[Bar,String]]
      notice([a] =~ Foo)
      notice([1] =~ Foo)
      notice([/x/] =~ Foo)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true', 'true', 'false'])
    end

    it 'will handle a non scalar correctly in combinations of nested aliased variants with array' do
      code = <<-CODE
      type Bar = Variant[Foo,Array[Integer]]
      type Foo = Variant[Bar,Array[String]]
      notice([a] =~ Foo)
      notice([1] =~ Foo)
      notice([/x/] =~ Foo)
      CODE
      expect(eval_and_collect_notices(code)).to eq(['true', 'true', 'false'])
    end

    it 'will not allow dynamic constructs in type definition' do
      code = <<-CODE
      type Foo = Enum[$facts[os][family]]
      notice(Foo)
      CODE
      expect{ eval_and_collect_notices(code) }.to raise_error(Puppet::Error,
        /The expression <\$facts\[os\]\[family\]> is not a valid type specification/)
    end
  end

  context 'Type mappings' do
    it 'can register a singe type mapping' do
      source = <<-CODE
        type MyModule::ImplementationRegistry = Object[{}]
        type Runtime[ruby, 'Puppet::Pops::Types::ImplementationRegistry'] = MyModule::ImplementationRegistry
        notice(true)
      CODE
      collect_notices(source) do |compiler|
        compiler.compile do |catalog|
          type = Loaders.implementation_registry.type_for_module(ImplementationRegistry)
          expect(type).to be_a(PObjectType)
          expect(type.name).to eql('MyModule::ImplementationRegistry')
          catalog
        end
      end
    end

    it 'can register a regexp based mapping' do
      source = <<-CODE
        type MyModule::TypeMismatchDescriber = Object[{}]
        type Runtime[ruby, [/^Puppet::Pops::Types::(\\w+)$/, 'MyModule::\\1']] = [/^MyModule::(\\w+)$/, 'Puppet::Pops::Types::\\1']
        notice(true)
      CODE
      collect_notices(source) do |compiler|
        compiler.compile do |catalog|
          type = Loaders.implementation_registry.type_for_module(TypeMismatchDescriber)
          expect(type).to be_a(PObjectType)
          expect(type.name).to eql('MyModule::TypeMismatchDescriber')
          catalog
        end
      end
    end

    it 'a type mapping affects type inference' do
      source = <<-CODE
        type MyModule::ImplementationRegistry = Object[{}]
        type Runtime[ruby, 'Puppet::Pops::Types::ImplementationRegistry'] = MyModule::ImplementationRegistry
        notice(true)
      CODE
      collect_notices(source) do |compiler|
        compiler.compile do |catalog|
          type = TypeCalculator.singleton.infer(Loaders.implementation_registry)
          expect(type).to be_a(PObjectType)
          expect(type.name).to eql('MyModule::ImplementationRegistry')
          catalog
        end
      end
    end
  end

  context 'When attempting to redefine a built in type' do
    it 'such as Integer, an error is raised' do
      code = <<-CODE
        type Integer = String
        notice 'hello' =~ Integer
      CODE
      expect{ eval_and_collect_notices(code) }.to raise_error(/Attempt to redefine entity 'type\/integer'. Originally set by Puppet-Type-System\/Static-Loader/)
    end
  end

  context 'instantiation via new_function is supported by' do
    let(:loader) { Loader::BaseLoader.new(nil, "types_unit_test_loader") }
    it 'Integer' do
      func_class = tf.integer.new_function(loader)
      expect(func_class).to be_a(Class)
      expect(func_class.superclass).to be(Puppet::Functions::Function)
    end

    it 'Optional[Integer]' do
      func_class = tf.optional(tf.integer).new_function(loader)
      expect(func_class).to be_a(Class)
      expect(func_class.superclass).to be(Puppet::Functions::Function)
    end
  end

  context 'instantiation via new_function is not supported by' do
    let(:loader) { Loader::BaseLoader.new(nil, "types_unit_test_loader") }

      it 'Any, Scalar, Collection' do
        [tf.any, tf.scalar, tf.collection ].each do |t|
        expect { t.new_function(loader)
        }.to raise_error(ArgumentError, /Creation of new instance of type '#{t.to_s}' is not supported/)
      end
    end
  end

end
end
end
