require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the new function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'yields converted value if given a block' do
    expect(compile_to_catalog(<<-MANIFEST
      $x = Integer.new('42') |$x| { $x+2 }
      notify { "${type($x, generalized)}, $x": }
    MANIFEST
    )).to have_resource('Notify[Integer, 44]')
  end

  it 'produces undef if given an undef value and type accepts it' do
    expect(compile_to_catalog(<<-MANIFEST
      $x = Optional[Integer].new(undef)
      notify { "one${x}word": }
    MANIFEST
    )).to have_resource('Notify[oneword]')
  end

  it 'errors if given undef and type does not accept the value' do
    expect{compile_to_catalog(<<-MANIFEST
      $x = Integer.new(undef)
      notify { "one${x}word": }
    MANIFEST
    )}.to raise_error(Puppet::Error, /expected an Integer value, got Undef/)
  end

  it 'errors if converted value is not assignable to the type' do
    expect{compile_to_catalog(<<-MANIFEST
      $x = Integer[1,5].new('42')
      notify { "one${x}word": }
    MANIFEST
    )}.to raise_error(Puppet::Error, /expected an Integer\[1, 5\] value, got Integer\[42, 42\]/)
  end

  context 'when invoked on NotUndef' do
    it 'produces an instance of the NotUndef nested type' do
      expect(compile_to_catalog(<<-MANIFEST
        $x = NotUndef[Integer].new(42)
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 42]')
    end

    it 'produces the given value when there is no type specified' do
      expect(compile_to_catalog(<<-MANIFEST
        $x = NotUndef.new(42)
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 42]')
    end
  end

  context 'when invoked on an Integer' do
    it 'produces 42 when given the integer 42' do
      expect(compile_to_catalog(<<-MANIFEST
        $x = Integer.new(42)
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 42]')
    end

    it 'produces 3 when given the float 3.1415' do
      expect(compile_to_catalog(<<-MANIFEST
        $x = Integer.new(3.1415)
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 3]')
    end

    it 'produces 0 from false' do
      expect(compile_to_catalog(<<-MANIFEST
        $x = Integer.new(false)
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 0]')
    end

    it 'produces 1 from true' do
      expect(compile_to_catalog(<<-MANIFEST
        $x = Integer.new(true)
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 1]')
    end

    context 'when prefixed by a sign' do
      { '+1'     => 1,
        '-1'     => -1,
        '+ 1'    => 1,
        '- 1'    => -1,
        '+0x10'  => 16,
        '+ 0x10' => 16,
        '-0x10'  => -16,
        '- 0x10' => -16
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}")
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end
    end

    context "when radix is not set it uses default and" do
      { "10"     => 10,
        "010"    => 8,
        "0x10"   => 16,
        "0X10"   => 16,
        '0B111'  => 7,
        '0b111'  => 7
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}")
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end
    end

    context "when radix is explicitly set to 'default' it" do
      { "10"     => 10,
        "010"    => 8,
        "0x10"   => 16,
        "0X10"   => 16,
        '0B111'  => 7,
        '0b111'  => 7
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", default)
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end
    end

    context "when radix is explicitly set to '2' it" do
      { "10"     => 2,
        "010"    => 2,
        "00010"  => 2,
        '0B111'  => 7,
        '0b111'  => 7,
        '+0B111' => 7,
        '-0b111' => -7,
        '+ 0B111'=> 7,
        '- 0b111'=> -7
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 2)
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end

      { '0x10'  => :error,
        '0X10'  => :error,
        '+0X10' => :error,
        '-0X10' => :error,
        '+ 0X10'=> :error,
        '- 0X10'=> :error
      }.each do |str, result|
        it "errors when given the non binary value compliant string '#{str}'" do
          expect{compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 2)
          MANIFEST
        )}.to raise_error(Puppet::Error, /invalid value/)
        end
      end
    end

    context "when radix is explicitly set to '8' it" do
      { "10"     => 8,
        "010"    => 8,
        "00010"  => 8,
        '+00010' => 8,
        '-00010' => -8,
        '+ 00010'=> 8,
        '- 00010'=> -8,
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 8)
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end

      { "0x10"  => :error,
        '0X10'  => :error,
        '0B10'  => :error,
        '0b10'  => :error,
        '+0b10' => :error,
        '-0b10' => :error,
        '+ 0b10'=> :error,
        '- 0b10'=> :error,
      }.each do |str, result|
        it "errors when given the non octal value compliant string '#{str}'" do
          expect{compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 8)
          MANIFEST
        )}.to raise_error(Puppet::Error, /invalid value/)
        end
      end
    end

    context "when radix is explicitly set to '16' it" do
      { "10"     => 16,
        "010"    => 16,
        "00010"  => 16,
        "0x10"   => 16,
        "0X10"   => 16,
        "0b1"    => 16*11+1,
        "0B1"    => 16*11+1,
        '+0B1'   => 16*11+1,
        '-0B1'   => -16*11-1,
        '+ 0B1'  => 16*11+1,
        '- 0B1'  => -16*11-1,
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 16)
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end

      { '0XGG'  => :error,
        '+0XGG' => :error,
        '-0XGG' => :error,
        '+ 0XGG'=> :error,
        '- 0XGG'=> :error,
      }.each do |str, result|
        it "errors when given the non octal value compliant string '#{str}'" do
          expect{compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 8)
          MANIFEST
        )}.to raise_error(Puppet::Error, /invalid value/)
        end
      end
    end

    context "when radix is explicitly set to '10' it" do
      { "10"     => 10,
        "010"    => 10,
        "00010"  => 10,
      }.each do |str, result|
        it "produces #{result} from the string '#{str}'" do
          expect(compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 10)
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          )).to have_resource("Notify[Integer, #{result}]")
        end
      end

      { '0X10'  => :error,
        '0b10'  => :error,
        '0B10'  => :error,
      }.each do |str, result|
        it "errors when given the non octal value compliant string '#{str}'" do
          expect{compile_to_catalog(<<-"MANIFEST"
            $x = Integer.new("#{str}", 10)
          MANIFEST
        )}.to raise_error(Puppet::Error, /invalid value/)
        end
      end
    end

    context "input can be given in long form " do
      { {'from' => "10", 'radix' => 2}     => 2,
        {'from' => "10", 'radix' => 8}     => 8,
        {'from' => "10", 'radix' => 10}    => 10,
        {'from' => "10", 'radix' => 16}    => 16,
        {'from' => "10", 'radix' => :default}    => 10,
      }.each do |options, result|
        it "produces #{result} from the long form '#{options}'" do
          src = <<-"MANIFEST"
            $x = Integer.new(#{options.to_s.gsub(/:/, '')})
            notify { "${type($x, generalized)}, $x": }
          MANIFEST
          expect(compile_to_catalog(src)).to have_resource("Notify[Integer, #{result}]")
        end
      end
    end

    context 'errors when' do
      it 'radix is wrong and when given directly' do
        expect{compile_to_catalog(<<-"MANIFEST"
          $x = Integer.new('10', 3)
        MANIFEST
      )}.to raise_error(Puppet::Error, /rejected: parameter 'radix'/m)
      end

      it 'radix is wrong and when given in long form' do
        expect{compile_to_catalog(<<-"MANIFEST"
          $x = Integer.new({from =>'10', radix=>3})
        MANIFEST
      )}.to raise_error(Puppet::Error, /rejected: parameter 'hash_args' entry 'radix'/m)
      end

      it 'value is not numeric and given directly' do
        expect{compile_to_catalog(<<-"MANIFEST"
          $x = Integer.new('eleven', 10)
        MANIFEST
      )}.to raise_error(Puppet::Error, /invalid value/)
      end

      it 'value is not numeric and given in long form' do
        expect{compile_to_catalog(<<-"MANIFEST"
      $x = Integer.new({from => 'eleven', radix => 10})
        MANIFEST
      )}.to raise_error(Puppet::Error, /invalid value/)
      end
    end
  end

  context 'when invoked on Numeric' do
    { 42 => "Notify[Integer, 42]",
      42.3 => "Notify[Float, 42.3]",
      "42.0" => "Notify[Float, 42.0]",
      "+42.0" => "Notify[Float, 42.0]",
      "-42.0" => "Notify[Float, -42.0]",
      "+ 42.0" => "Notify[Float, 42.0]",
      "- 42.0" => "Notify[Float, -42.0]",
      "42.3" => "Notify[Float, 42.3]",
      "0x10" => "Notify[Integer, 16]",
      "010" => "Notify[Integer, 8]",
      "0.10" => "Notify[Float, 0.1]",
      "0b10" => "Notify[Integer, 2]",
      false => "Notify[Integer, 0]",
      true => "Notify[Integer, 1]",
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect}" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Numeric.new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    it "produces a result when long from hash {from => val} is used" do
      expect(compile_to_catalog(<<-MANIFEST
        $x = Numeric.new({from=>'42'})
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Integer, 42]')
    end
  end

  context 'when invoked on Float' do
    { 42     => "Notify[Float, 42.0]",
      42.3   => "Notify[Float, 42.3]",
      "42.0" => "Notify[Float, 42.0]",
      "+42.0" => "Notify[Float, 42.0]",
      "-42.0" => "Notify[Float, -42.0]",
      "+ 42.0" => "Notify[Float, 42.0]",
      "- 42.0" => "Notify[Float, -42.0]",
      "42.3" => "Notify[Float, 42.3]",
      "0x10" => "Notify[Float, 16.0]",
      "010"  => "Notify[Float, 10.0]",
      "0.10" => "Notify[Float, 0.1]",
      false  => "Notify[Float, 0.0]",
      true   => "Notify[Float, 1.0]",
      '0b10'  => "Notify[Float, 2.0]",
      '0B10'  => "Notify[Float, 2.0]",
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect}" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Float.new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    it "produces a result when long from hash {from => val} is used" do
      expect(compile_to_catalog(<<-MANIFEST
        $x = Float.new({from=>42})
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Float, 42.0]')
    end
  end

  context 'when invoked on Boolean' do
    { true     => 'Notify[Boolean, true]',
      false    => 'Notify[Boolean, false]',
      0        => 'Notify[Boolean, false]',
      1        => 'Notify[Boolean, true]',
      0.0      => 'Notify[Boolean, false]',
      1.0      => 'Notify[Boolean, true]',

      'true'   => 'Notify[Boolean, true]',
      'TrUe'   => 'Notify[Boolean, true]',
      'yes'    => 'Notify[Boolean, true]',
      'YeS'    => 'Notify[Boolean, true]',
      'y'      => 'Notify[Boolean, true]',
      'Y'      => 'Notify[Boolean, true]',

      'false'  => 'Notify[Boolean, false]',
      'no'     => 'Notify[Boolean, false]',
      'n'      => 'Notify[Boolean, false]',
      'FalSE'  => 'Notify[Boolean, false]',
      'nO'     => 'Notify[Boolean, false]',
      'N'      => 'Notify[Boolean, false]',
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect}" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Boolean.new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    it "errors when given an non boolean representation like the string 'hello'" do
      expect{compile_to_catalog(<<-"MANIFEST"
        $x = Boolean.new('hello')
      MANIFEST
      )}.to raise_error(Puppet::Error, /cannot be converted to Boolean/)
    end

    it "does not convert an undef (as may be expected, but is handled as every other undef)" do
      expect{compile_to_catalog(<<-"MANIFEST"
        $x = Boolean.new(undef)
      MANIFEST
      )}.to raise_error(Puppet::Error, /expected a Boolean value, got Undef/)
    end
  end

  context 'when invoked on Array' do
    { []            => 'Notify[Array[Unit], []]',
      [true]        => 'Notify[Array[Boolean], [true]]',
      {'a'=>true, 'b' => false}   => 'Notify[Array[Array[Scalar]], [[a, true], [b, false]]]',
      'abc'         => 'Notify[Array[String], [a, b, c]]',
      3             => 'Notify[Array[Integer], [0, 1, 2]]',
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect} and wrap is not given" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Array.new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    {
      true          => /cannot be converted to Array/,
      42.3          => /cannot be converted to Array/,
    }.each do |input, error_match|
      it "errors when given an non convertible #{input.inspect} when wrap is not given" do
        expect{compile_to_catalog(<<-"MANIFEST"
          $x = Array.new(#{input.inspect})
        MANIFEST
        )}.to raise_error(Puppet::Error, error_match)
      end
    end

    { []            => 'Notify[Array[Unit], []]',
      [true]        => 'Notify[Array[Boolean], [true]]',
      {'a'=>true}   => 'Notify[Array[Hash[String, Boolean]], [{a => true}]]',
      'hello'       => 'Notify[Array[String], [hello]]',
      true          => 'Notify[Array[Boolean], [true]]',
      42            => 'Notify[Array[Integer], [42]]',
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect} and wrap is given" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Array.new(#{input.inspect}, true)
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end
  end

  context 'when invoked on Tuple' do
    { 'abc'         => 'Notify[Array[String], [a, b, c]]',
      3             => 'Notify[Array[Integer], [0, 1, 2]]',
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect} and wrap is not given" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Tuple[Any,3].new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    it "errors when tuple requirements are not met" do
      expect{compile_to_catalog(<<-"MANIFEST"
        $x = Tuple[Integer,6].new(3)
      MANIFEST
      )}.to raise_error(Puppet::Error, /expected size to be at least 6, got 3/)
    end
  end

  context 'when invoked on Hash' do
    { {}            => 'Notify[Hash[0, 0], {}]',
      []            => 'Notify[Hash[0, 0], {}]',
      {'a'=>true}   => 'Notify[Hash[String, Boolean], {a => true}]',
      [1,2,3,4]     => 'Notify[Hash[Integer, Integer], {1 => 2, 3 => 4}]',
      [[1,2],[3,4]] => 'Notify[Hash[Integer, Integer], {1 => 2, 3 => 4}]',
      'abcd'        => 'Notify[Hash[String, String], {a => b, c => d}]',
      4             => 'Notify[Hash[Integer, Integer], {0 => 1, 2 => 3}]',

    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect}" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Hash.new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    { true             => /cannot be converted to Hash/,
      [1,2,3]          => /odd number of arguments for Hash/,
    }.each do |input, error_match|
      it "errors when given an non convertible #{input.inspect}" do
        expect{compile_to_catalog(<<-"MANIFEST"
          $x = Hash.new(#{input.inspect})
        MANIFEST
        )}.to raise_error(Puppet::Error, error_match)
      end
    end
  end

  context 'when invoked on Struct' do
    { {'a' => 2}      => 'Notify[Struct[{\'a\' => Integer[2, 2]}], {a => 2}]',
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect}" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = Struct[{a => Integer[2]}].new(#{input.inspect})
          notify { "${type($x)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end

    it "errors when tuple requirements are not met" do
      expect{compile_to_catalog(<<-"MANIFEST"
        $x = Struct[{a => Integer[2]}].new({a => 0})
      MANIFEST
      )}.to raise_error(Puppet::Error, /entry 'a' expected an Integer\[2, default\]/)
    end
  end

  context 'when invoked on String' do
    { {}            => 'Notify[String, {}]',
      []            => 'Notify[String, []]',
      {'a'=>true}   => "Notify[String, {'a' => true}]",
      [1,2,3,4]     => 'Notify[String, [1, 2, 3, 4]]',
      [[1,2],[3,4]] => 'Notify[String, [[1, 2], [3, 4]]]',
      'abcd'        => 'Notify[String, abcd]',
      4             => 'Notify[String, 4]',
    }.each do |input, result|
      it "produces #{result} when given the value #{input.inspect}" do
        expect(compile_to_catalog(<<-MANIFEST
          $x = String.new(#{input.inspect})
          notify { "${type($x, generalized)}, $x": }
        MANIFEST
        )).to have_resource(result)
      end
    end
  end

  context 'when invoked on a type alias' do
    it 'delegates the new to the aliased type' do
      expect(compile_to_catalog(<<-MANIFEST
        type X = Boolean
        $x = X.new('yes')
        notify { "${type($x, generalized)}, $x": }
      MANIFEST
      )).to have_resource('Notify[Boolean, true]')
    end
  end
end
