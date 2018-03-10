require 'spec_helper'
require 'puppet/pops'

describe 'The string converter' do
  let(:converter) { Puppet::Pops::Types::StringConverter.singleton }
  let(:factory) { Puppet::Pops::Types::TypeFactory }
  let(:format) { Puppet::Pops::Types::StringConverter::Format }
  let(:binary) { Puppet::Pops::Types::PBinaryType::Binary }

  describe 'helper Format' do
    it 'parses a single character like "%d" as a format' do
      fmt = format.new("%d")
      expect(fmt.format()).to be(:d)
      expect(fmt.alt()).to be(false)
      expect(fmt.left()).to be(false)
      expect(fmt.width()).to be_nil
      expect(fmt.prec()).to be_nil
      expect(fmt.plus()).to eq(:ignore)
    end

    it 'alternative form can be given with "%#d"' do
      fmt = format.new("%#d")
      expect(fmt.format()).to be(:d)
      expect(fmt.alt()).to be(true)
    end

    it 'left adjust can be given with "%-d"' do
      fmt = format.new("%-d")
      expect(fmt.format()).to be(:d)
      expect(fmt.left()).to be(true)
    end

    it 'plus sign can be used to indicate how positive numbers are displayed' do
      fmt = format.new("%+d")
      expect(fmt.format()).to be(:d)
      expect(fmt.plus()).to eq(:plus)
    end

    it 'a space can be used to output " " instead of "+" for positive numbers' do
      fmt = format.new("% d")
      expect(fmt.format()).to be(:d)
      expect(fmt.plus()).to eq(:space)
    end

    it 'padding with zero can be specified with a "0" flag' do
      fmt = format.new("%0d")
      expect(fmt.format()).to be(:d)
      expect(fmt.zero_pad()).to be(true)
    end

    it 'width can be specified as an integer >= 1' do
      fmt = format.new("%1d")
      expect(fmt.format()).to be(:d)
      expect(fmt.width()).to be(1)
      fmt = format.new("%10d")
      expect(fmt.width()).to be(10)
    end

    it 'precision can be specified as an integer >= 0' do
      fmt = format.new("%.0d")
      expect(fmt.format()).to be(:d)
      expect(fmt.prec()).to be(0)
      fmt = format.new("%.10d")
      expect(fmt.prec()).to be(10)
    end

    it 'width and precision can both be specified' do
      fmt = format.new("%2.3d")
      expect(fmt.format()).to be(:d)
      expect(fmt.width()).to be(2)
      expect(fmt.prec()).to be(3)
    end

    [
      '[', '{', '(', '<', '|',
    ].each do | delim |
      it "a container delimiter pair can be set with '#{delim}'" do
        fmt = format.new("%#{delim}d")
        expect(fmt.format()).to be(:d)
        expect(fmt.delimiters()).to eql(delim)
      end
    end

    it "Is an error to specify different delimiters at the same time" do
      expect do
        format.new("%[{d")
      end.to raise_error(/Only one of the delimiters/)
    end

    it "Is an error to have trailing characters after the format" do
      expect do
        format.new("%dv")
      end.to raise_error(/The format '%dv' is not a valid format/)
    end

    it "Is an error to specify the same flag more than once" do
      expect do
        format.new("%[[d")
      end.to raise_error(/The same flag can only be used once/)
    end
  end

  context 'when converting to string' do
    {
      42                   => "42",
      3.14                 => "3.140000",
      "hello world"        => "hello world",
      "hello\tworld"       => "hello\tworld",
    }.each do |from, to|
      it "the string value of #{from} is '#{to}'" do
        expect(converter.convert(from, :default)).to eq(to)
      end
    end

    it 'float point value decimal digits can be specified' do
      string_formats = { Puppet::Pops::Types::PFloatType::DEFAULT => '%.2f'}
      expect(converter.convert(3.14, string_formats)).to eq('3.14')
    end

    it 'when specifying format for one type, other formats are not affected' do
      string_formats = { Puppet::Pops::Types::PFloatType::DEFAULT => '%.2f'}
      expect(converter.convert('3.1415', string_formats)).to eq('3.1415')
    end

    context 'The %p format for string produces' do
      let!(:string_formats) { { Puppet::Pops::Types::PStringType::DEFAULT => '%p'} }
      it 'double quoted result for string that contains control characters' do
         expect(converter.convert("hello\tworld.\r\nSun is brigth today.", string_formats)).to eq('"hello\\tworld.\\r\\nSun is brigth today."')
      end

      it 'singe quoted result for string that is plain ascii without \\, $ or control characters' do
        expect(converter.convert('hello world', string_formats)).to eq("'hello world'")
      end

      it 'quoted 5-byte unicode chars' do
        expect(converter.convert("smile \u{1f603}.", string_formats)).to eq("'smile \u{1F603}.'")
      end

      it 'quoted 2-byte unicode chars' do
        expect(converter.convert("esc \u{1b}.", string_formats)).to eq('"esc \\u{1B}."')
      end

      it 'escape for $ in double quoted string' do
        # Use \n in string to force double quotes
        expect(converter.convert("escape the $ sign\n", string_formats)).to eq('"escape the \$ sign\n"')
      end

      it 'no escape for $ in single quoted string' do
        expect(converter.convert('don\'t escape the $ sign', string_formats)).to eq("'don\\'t escape the $ sign'")
      end

      it 'escape for double quote but not for single quote in double quoted string' do
        # Use \n in string to force double quotes
        expect(converter.convert("the ' single and \" double quote\n", string_formats)).to eq('"the \' single and \\" double quote\n"')
      end

      it 'escape for single quote but not for double quote in single quoted string' do
        expect(converter.convert('the \' single and " double quote', string_formats)).to eq("'the \\' single and \" double quote'")
      end

      it 'no escape for #' do
        expect(converter.convert('do not escape #{x}', string_formats)).to eq('\'do not escape #{x}\'')
      end

      it 'escape for last \\' do
        expect(converter.convert('escape the last \\', string_formats)).to eq("'escape the last \\'")
      end
    end

    {
      '%s'   => 'hello::world',
      '%p'   => "'hello::world'",
      '%c'   => 'Hello::world',
      '%#c'   => "'Hello::world'",
      '%u'   => 'HELLO::WORLD',
      '%#u'   => "'HELLO::WORLD'",
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => fmt}
        expect(converter.convert('hello::world', string_formats)).to eq(result)
      end
    end

    {
      '%c'   => 'Hello::world',
      '%#c'  => "'Hello::world'",
      '%d'   => 'hello::world',
      '%#d'  => "'hello::world'",
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => fmt}
        expect(converter.convert('HELLO::WORLD', string_formats)).to eq(result)
      end
    end

    {
      [nil, '%.1p']  => 'u',
      [nil, '%#.2p'] => '"u',
      [:default, '%.1p'] => 'd',
      [true, '%.2s'] => 'tr',
      [true, '%.2y'] => 'ye',
    }.each do |args, result |
      it "the format #{args[1]} produces #{result} for value #{args[0]}" do
        expect(converter.convert(*args)).to eq(result)
      end
    end

    {
      '   a b  ' => 'a b',
      'a b  '    => 'a b',
      '   a b'   => 'a b',
    }.each do |input, result |
      it "the input #{input} is trimmed to #{result} by using format '%t'" do
        string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => '%t'}
        expect(converter.convert(input, string_formats)).to eq(result)
      end
    end

    {
      '   a b  ' => "'a b'",
      'a b  '    => "'a b'",
      '   a b'   => "'a b'",
    }.each do |input, result |
      it "the input #{input} is trimmed to #{result} by using format '%#t'" do
        string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => '%#t'}
        expect(converter.convert(input, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => "%k"}
      converter.convert('wat', string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of String type - expected one of the characters 'cCudspt'/)
    end

    it 'Width pads a string left with spaces to given width' do
      string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => '%6s'}
      expect(converter.convert("abcd", string_formats)).to eq('  abcd')
    end

    it 'Width pads a string right with spaces to given width and - flag' do
      string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => '%-6s'}
      expect(converter.convert("abcd", string_formats)).to eq('abcd  ')
    end

    it 'Precision truncates the string if precision < length' do
      string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => '%-6.2s'}
      expect(converter.convert("abcd", string_formats)).to eq('ab    ')
    end

    {
      '%4.2s'   => '  he',
      '%4.2p'   => "  'h",
      '%4.2c'   => '  He',
      '%#4.2c'  => "  'H",
      '%4.2u'   => '  HE',
      '%#4.2u'  => "  'H",
      '%4.2d'   => '  he',
      '%#4.2d'  => "  'h"
    }.each do |fmt, result |
      it "width and precision can be combined with #{fmt}" do
        string_formats = { Puppet::Pops::Types::PStringType::DEFAULT => fmt}
        expect(converter.convert('hello::world', string_formats)).to eq(result)
      end
    end

  end

  context 'when converting integer' do
    it 'the default string representation is decimal' do
      expect(converter.convert(42, :default)).to eq('42')
    end

    {
      '%s'      => '18',
      '%4.1s'   => '   1',
      '%p'      => '18',
      '%4.2p'   => '  18',
      '%4.1p'   => '   1',
      '%#s'     => '"18"',
      '%#6.4s'  => '  "18"',
      '%#p'     => '18',
      '%#6.4p'  => '    18',
      '%d'      => '18',
      '%4.1d'   => '  18',
      '%4.3d'   => ' 018',
      '%x'      => '12',
      '%4.3x'   => ' 012',
      '%#x'     => '0x12',
      '%#6.4x'  => '0x0012',
      '%X'      => '12',
      '%4.3X'   => ' 012',
      '%#X'     => '0X12',
      '%#6.4X'  => '0X0012',
      '%o'      => '22',
      '%4.2o'   => '  22',
      '%#o'     => '022',
      '%#6.4o'  => '  0022',
      '%b'      => '10010',
      '%7.6b'   => ' 010010',
      '%#b'     => '0b10010',
      '%#9.6b'  => ' 0b010010',
      '%#B'     => '0B10010',
      '%#9.6B'  => ' 0B010010',
      # Integer to float then a float format - fully tested for float
      '%e'      => '1.800000e+01',
      '%E'      => '1.800000E+01',
      '%f'      => '18.000000',
      '%g'      => '18',
      '%a'      => '0x1.2p+4',
      '%A'      => '0X1.2P+4',
      '%.1f'    => '18.0',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PIntegerType::DEFAULT => fmt}
        expect(converter.convert(18, string_formats)).to eq(result)
      end
    end

    it 'produces a unicode char string by using format %c' do
      string_formats = { Puppet::Pops::Types::PIntegerType::DEFAULT => '%c'}
      expect(converter.convert(0x1F603, string_formats)).to eq("\u{1F603}")
    end

    it 'produces a quoted unicode char string by using format %#c' do
      string_formats = { Puppet::Pops::Types::PIntegerType::DEFAULT => '%#c'}
      expect(converter.convert(0x1F603, string_formats)).to eq("\"\u{1F603}\"")
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PIntegerType::DEFAULT => "%k"}
      converter.convert(18, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Integer type - expected one of the characters 'dxXobBeEfgGaAspc'/)
    end
  end

  context 'when converting float' do
    it 'the default string representation is decimal' do
      expect(converter.convert(42.0, :default)).to eq('42.000000')
    end

    {
      '%s'      => '18.0',
      '%#s'     => '"18.0"',
      '%5s'     => ' 18.0',
      '%#8s'    => '  "18.0"',
      '%05.1s'  => '    1',
      '%p'      => '18.0',
      '%7.2p'   => '     18',

      '%e'      => '1.800000e+01',
      '%+e'     => '+1.800000e+01',
      '% e'     => ' 1.800000e+01',
      '%.2e'    => '1.80e+01',
      '%10.2e'  => '  1.80e+01',
      '%-10.2e' => '1.80e+01  ',
      '%010.2e' => '001.80e+01',

      '%E'      => '1.800000E+01',
      '%+E'     => '+1.800000E+01',
      '% E'     => ' 1.800000E+01',
      '%.2E'    => '1.80E+01',
      '%10.2E'  => '  1.80E+01',
      '%-10.2E' => '1.80E+01  ',
      '%010.2E' => '001.80E+01',

      '%f'      => '18.000000',
      '%+f'     => '+18.000000',
      '% f'     => ' 18.000000',
      '%.2f'    => '18.00',
      '%10.2f'  => '     18.00',
      '%-10.2f' => '18.00     ',
      '%010.2f' => '0000018.00',

      '%g'      => '18',
      '%5g'     => '   18',
      '%05g'    => '00018',
      '%-5g'    => '18   ',
      '%5.4g'   => '   18',  # precision has no effect

      '%a'      => '0x1.2p+4',
      '%.4a'    => '0x1.2000p+4',
      '%10a'    => '  0x1.2p+4',
      '%010a'    => '0x001.2p+4',
      '%-10a'   => '0x1.2p+4  ',
      '%A'      => '0X1.2P+4',
      '%.4A'      => '0X1.2000P+4',
      '%10A'    => '  0X1.2P+4',
      '%-10A'   => '0X1.2P+4  ',
      '%010A'   => '0X001.2P+4',

      # integer formats fully tested for integer
      '%d'      => '18',
      '%x'      => '12',
      '%X'      => '12',
      '%o'      => '22',
      '%b'      => '10010',
      '%#B'     => '0B10010',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PFloatType::DEFAULT => fmt}
        expect(converter.convert(18.0, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PFloatType::DEFAULT => "%k"}
      converter.convert(18.0, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Float type - expected one of the characters 'dxXobBeEfgGaAsp'/)
    end
  end

  context 'when converting undef' do
    it 'the default string representation is empty string' do
      expect(converter.convert(nil, :default)).to eq('')
    end

    { "%u"  => "undef",
      "%#u" => "undefined",
      "%s"  => "",
      "%#s"  => '""',
      "%p"  => 'undef',
      "%#p"  => '"undef"',
      "%n"  => 'nil',
      "%#n" => 'null',
      "%v"  => 'n/a',
      "%V"  => 'N/A',
      "%d"  => 'NaN',
      "%x"  => 'NaN',
      "%o"  => 'NaN',
      "%b"  => 'NaN',
      "%B"  => 'NaN',
      "%e"  => 'NaN',
      "%E"  => 'NaN',
      "%f"  => 'NaN',
      "%g"  => 'NaN',
      "%G"  => 'NaN',
      "%a"  => 'NaN',
      "%A"  => 'NaN',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PUndefType::DEFAULT => fmt}
        expect(converter.convert(nil, string_formats)).to eq(result)
      end
    end

    { "%7u"    => "  undef",
      "%-7u"   => "undef  ",
      "%#10u"  => " undefined",
      "%#-10u" => "undefined ",
      "%7.2u"  => "     un",
      "%4s"    => "    ",
      "%#4s"   => '  ""',
      "%7p"    => '  undef',
      "%7.1p"  => '      u',
      "%#8p"   => ' "undef"',
      "%5n"    => '  nil',
      "%.1n"   => 'n',
      "%-5n"   => 'nil  ',
      "%#5n"   => ' null',
      "%#-5n"  => 'null ',
      "%5v"    => '  n/a',
      "%5.2v"  => '   n/',
      "%-5v"   => 'n/a  ',
      "%5V"    => '  N/A',
      "%5.1V"  => '    N',
      "%-5V"   => 'N/A  ',
      "%5d"    => '  NaN',
      "%5.2d"  => '   Na',
      "%-5d"   => 'NaN  ',
      "%5x"    => '  NaN',
      "%5.2x"  => '   Na',
      "%-5x"   => 'NaN  ',
      "%5o"    => '  NaN',
      "%5.2o"  => '   Na',
      "%-5o"   => 'NaN  ',
      "%5b"    => '  NaN',
      "%5.2b"  => '   Na',
      "%-5b"   => 'NaN  ',
      "%5B"    => '  NaN',
      "%5.2B"  => '   Na',
      "%-5B"   => 'NaN  ',
      "%5e"    => '  NaN',
      "%5.2e"  => '   Na',
      "%-5e"   => 'NaN  ',
      "%5E"    => '  NaN',
      "%5.2E"  => '   Na',
      "%-5E"   => 'NaN  ',
      "%5f"    => '  NaN',
      "%5.2f"  => '   Na',
      "%-5f"   => 'NaN  ',
      "%5g"    => '  NaN',
      "%5.2g"  => '   Na',
      "%-5g"   => 'NaN  ',
      "%5G"    => '  NaN',
      "%5.2G"  => '   Na',
      "%-5G"   => 'NaN  ',
      "%5a"    => '  NaN',
      "%5.2a"  => '   Na',
      "%-5a"   => 'NaN  ',
      "%5A"    => '  NaN',
      "%5.2A"  => '   Na',
      "%-5A"   => 'NaN  ',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PUndefType::DEFAULT => fmt}
        expect(converter.convert(nil, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PUndefType::DEFAULT => "%k"}
      converter.convert(nil, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Undef type - expected one of the characters 'nudxXobBeEfgGaAvVsp'/)
    end
  end

  context 'when converting default' do
    it 'the default string representation is unquoted "default"' do
      expect(converter.convert(:default, :default)).to eq('default')
    end

    { "%d"  => 'default',
      "%D"  => 'Default',
      "%#d" => '"default"',
      "%#D" => '"Default"',
      "%s"  => 'default',
      "%p"  => 'default',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PDefaultType::DEFAULT => fmt}
        expect(converter.convert(:default, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PDefaultType::DEFAULT => "%k"}
      converter.convert(:default, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Default type - expected one of the characters 'dDsp'/)
    end
  end

  context 'when converting boolean true' do
    it 'the default string representation is unquoted "true"' do
      expect(converter.convert(true, :default)).to eq('true')
    end

    { "%t"   => 'true',
      "%#t"  => 't',
      "%T"   => 'True',
      "%#T"  => 'T',
      "%s"   => 'true',
      "%p"   => 'true',
      "%d"   => '1',
      "%x"   => '1',
      "%#x"  => '0x1',
      "%o"   => '1',
      "%#o"  => '01',
      "%b"   => '1',
      "%#b"  => '0b1',
      "%#B"  => '0B1',
      "%e"   => '1.000000e+00',
      "%f"   => '1.000000',
      "%g"   => '1',
      "%a"   => '0x1p+0',
      "%A"   => '0X1P+0',
      "%.1f" => '1.0',
      "%y"   => 'yes',
      "%Y"   => 'Yes',
      "%#y"  => 'y',
      "%#Y"  => 'Y',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PBooleanType::DEFAULT => fmt}
        expect(converter.convert(true, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PBooleanType::DEFAULT => "%k"}
      converter.convert(true, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Boolean type - expected one of the characters 'tTyYdxXobBeEfgGaAsp'/)
    end

  end

  context 'when converting boolean false' do
    it 'the default string representation is unquoted "false"' do
      expect(converter.convert(false, :default)).to eq('false')
    end

    { "%t"   => 'false',
      "%#t"  => 'f',
      "%T"   => 'False',
      "%#T"  => 'F',
      "%s"   => 'false',
      "%p"   => 'false',
      "%d"   => '0',
      "%x"   => '0',
      "%#x"  => '0',
      "%o"   => '0',
      "%#o"  => '0',
      "%b"   => '0',
      "%#b"  => '0',
      "%#B"  => '0',
      "%e"   => '0.000000e+00',
      "%E"   => '0.000000E+00',
      "%f"   => '0.000000',
      "%g"   => '0',
      "%a"   => '0x0p+0',
      "%A"   => '0X0P+0',
      "%.1f" => '0.0',
      "%y"   => 'no',
      "%Y"   => 'No',
      "%#y"  => 'n',
      "%#Y"  => 'N',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PBooleanType::DEFAULT => fmt}
        expect(converter.convert(false, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PBooleanType::DEFAULT => "%k"}
      converter.convert(false, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Boolean type - expected one of the characters 'tTyYdxXobBeEfgGaAsp'/)
    end
  end

  context 'when converting array' do
    it 'the default string representation is using [] delimiters, joins with ',' and uses %p for values' do
      expect(converter.convert(["hello", "world"], :default)).to eq("['hello', 'world']")
    end

    { "%s"  => "[1, 'hello']",
      "%p"  => "[1, 'hello']",
      "%a"  => "[1, 'hello']",
      "%<a"  => "<1, 'hello'>",
      "%[a"  => "[1, 'hello']",
      "%(a"  => "(1, 'hello')",
      "%{a"  => "{1, 'hello'}",
      "% a"  => "1, 'hello'",

      {'format' => '%(a',
        'separator' => ' '
      } => "(1 'hello')",

      {'format' => '%(a',
        'separator' => ''
      } => "(1'hello')",

      {'format' => '%|a',
        'separator' => ' '
      } => "|1 'hello'|",

      {'format' => '%(a',
        'separator' => ' ',
        'string_formats' => {Puppet::Pops::Types::PIntegerType::DEFAULT => '%#x'}
      } => "(0x1 'hello')",
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => fmt}
        expect(converter.convert([1, "hello"], string_formats)).to eq(result)
      end
    end

    it "multiple rules selects most specific" do
      short_array_t = factory.array_of(factory.integer, factory.range(1,2))
      long_array_t = factory.array_of(factory.integer, factory.range(3,100))
      string_formats = {
        short_array_t => "%(a",
        long_array_t  => "%[a",
      }
      expect(converter.convert([1, 2], string_formats)).to eq('(1, 2)')
      expect(converter.convert([1, 2, 3], string_formats)).to eq('[1, 2, 3]')
    end

    it 'indents elements in alternate mode' do
      string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#a', 'separator' =>", " } }
      # formatting matters here
      result = [
       "[1, 2, 9, 9,",
       "  [3, 4],",
       "  [5,",
       "    [6, 7]],",
       "  8, 9]"
       ].join("\n")

     formatted = converter.convert([1, 2, 9, 9, [3, 4], [5, [6, 7]], 8, 9], string_formats)
     expect(formatted).to eq(result)
    end

    it 'treats hashes as nested arrays wrt indentation' do
      string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#a', 'separator' =>", " } }
      # formatting matters here
      result = [
       "[1, 2, 9, 9,",
       "  {3 => 4, 5 => 6},",
       "  [5,",
       "    [6, 7]],",
       "  8, 9]"
       ].join("\n")

     formatted = converter.convert([1, 2, 9, 9, {3  => 4, 5 => 6}, [5, [6, 7]], 8, 9], string_formats)
     expect(formatted).to eq(result)
    end

    it 'indents and breaks when a sequence > given width, in alternate mode' do
      string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#3a', 'separator' =>", " } }
      # formatting matters here
      result = [
       "[ 1,",
       "  2,",
       "  90,", # this sequence has length 4 (1,2,90) which is > 3
       "  [3, 4],",
       "  [5,",
       "    [6, 7]],",
       "  8,",
       "  9]",
       ].join("\n")

     formatted = converter.convert([1, 2, 90, [3, 4], [5, [6, 7]], 8, 9], string_formats)
     expect(formatted).to eq(result)
    end

    it 'indents and breaks when a sequence (placed last) > given width, in alternate mode' do
      string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#3a', 'separator' =>", " } }
      # formatting matters here
      result = [
       "[ 1,",
       "  2,",
       "  9,", # this sequence has length 3 (1,2,9) which does not cause breaking on each
       "  [3, 4],",
       "  [5,",
       "    [6, 7]],",
       "  8,",
       "  900]", # this sequence has length 4 (8, 900) which causes breaking on each
       ].join("\n")

     formatted = converter.convert([1, 2, 9, [3, 4], [5, [6, 7]], 8, 900], string_formats)
     expect(formatted).to eq(result)
    end

    it 'indents and breaks nested sequences when one is placed first' do
      string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#a', 'separator' =>", " } }
      # formatting matters here
      result = [
       "[",
       "  [",
       "    [1, 2,",
       "      [3, 4]]],",
       "  [5,",
       "    [6, 7]],",
       "  8, 900]",
       ].join("\n")

     formatted = converter.convert([[[1, 2, [3, 4]]], [5, [6, 7]], 8, 900], string_formats)
     expect(formatted).to eq(result)
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => "%k"}
      converter.convert([1,2], string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Array type - expected one of the characters 'asp'/)
    end
  end

  context 'when converting hash' do
    it 'the default string representation is using {} delimiters, joins with '=>' and uses %p for values' do
      expect(converter.convert({"hello" => "world"}, :default)).to eq("{'hello' => 'world'}")
    end

    { "%s"  => "{1 => 'world'}",
      "%p"  => "{1 => 'world'}",
      "%h"  => "{1 => 'world'}",
      "%a"  => "[[1, 'world']]",
      "%<h"  => "<1 => 'world'>",
      "%[h"  => "[1 => 'world']",
      "%(h"  => "(1 => 'world')",
      "%{h"  => "{1 => 'world'}",
      "% h"  => "1 => 'world'",

      {'format' => '%(h',
        'separator2' => ' '
      } => "(1 'world')",

      {'format' => '%(h',
        'separator2' => ' ',
        'string_formats' => {Puppet::Pops::Types::PIntegerType::DEFAULT => '%#x'}
      } => "(0x1 'world')",
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PHashType::DEFAULT => fmt}
        expect(converter.convert({1 => "world"}, string_formats)).to eq(result)
      end
    end

    {  "%s"  => "{1 => 'hello', 2 => 'world'}",

       {'format' => '%(h',
         'separator2' => ' '
       } => "(1 'hello', 2 'world')",

       {'format' => '%(h',
         'separator' => '',
         'separator2' => ''
       } => "(1'hello'2'world')",

       {'format' => '%(h',
         'separator' => ' >> ',
         'separator2' => ' <=> ',
         'string_formats' => {Puppet::Pops::Types::PIntegerType::DEFAULT => '%#x'}
       } => "(0x1 <=> 'hello' >> 0x2 <=> 'world')",
     }.each do |fmt, result |
       it "the format #{fmt} produces #{result}" do
         string_formats = { Puppet::Pops::Types::PHashType::DEFAULT => fmt}
         expect(converter.convert({1 => "hello", 2 => "world"}, string_formats)).to eq(result)
       end
     end

    it 'indents elements in alternative mode #' do
      string_formats = {
        Puppet::Pops::Types::PHashType::DEFAULT => {
          'format' => '%#h',
        }
      }
      # formatting matters here
      result = [
       "{",
       "  1 => 'hello',",
       "  2 => {",
       "    3 => 'world'",
       "  }",
       "}"
       ].join("\n")

      expect(converter.convert({1 => "hello", 2 => {3=> "world"}}, string_formats)).to eq(result)
    end

    context "containing an array" do
      it 'the hash and array renders without breaks and indentation by default' do
        result = "{1 => [1, 2, 3]}"
        formatted = converter.convert({ 1 => [1, 2, 3] }, :default)
        expect(formatted).to eq(result)
      end

      it 'the array renders with breaks if so specified' do
        string_formats = { Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#1a', 'separator' =>"," } }
        result = [
        "{1 => [ 1,",
        "    2,",
        "    3]}"
        ].join("\n")
        formatted = converter.convert({ 1 => [1, 2, 3] }, string_formats)
        expect(formatted).to eq(result)
      end

      it 'both hash and array renders with breaks and indentation if so specified for both' do
        string_formats = {
          Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%#1a', 'separator' =>", " },
          Puppet::Pops::Types::PHashType::DEFAULT => { 'format' => '%#h', 'separator' =>"," }
        }
        result = [
        "{",
        "  1 => [ 1,",
        "    2,",
        "    3]",
        "}"
        ].join("\n")
        formatted = converter.convert({ 1 => [1, 2, 3] }, string_formats)
        expect(formatted).to eq(result)
      end

      it 'hash, but not array is rendered with breaks and indentation if so specified only for the hash' do
        string_formats = {
          Puppet::Pops::Types::PArrayType::DEFAULT => { 'format' => '%a', 'separator' =>", " },
          Puppet::Pops::Types::PHashType::DEFAULT => { 'format' => '%#h', 'separator' =>"," }
        }
        result = [
        "{",
        "  1 => [1, 2, 3]",
        "}"
        ].join("\n")
        formatted = converter.convert({ 1 => [1, 2, 3] }, string_formats)
        expect(formatted).to eq(result)
      end
    end

    context 'that is subclassed' do
      let(:array) { ['a', 2] }
      let(:derived_array) do
        Class.new(Array) do
          def to_a
            self # Dead wrong! Should return a plain Array copy
          end
        end.new(array)
      end
      let(:derived_with_to_a) do
        Class.new(Array) do
          def to_a
            super
          end
        end.new(array)
      end

      let(:hash) { {'first' => 1, 'second' => 2} }
      let(:derived_hash) do
        Class.new(Hash)[hash]
      end
      let(:derived_with_to_hash) do
        Class.new(Hash) do
          def to_hash
            {}.merge(self)
          end
        end[hash]
      end

      it 'formats a derived array as a Runtime' do
        expect(converter.convert(array)).to eq('[\'a\', 2]')
        expect(converter.convert(derived_array)).to eq('["a", 2]')
      end

      it 'formats a derived array with #to_a retuning plain Array as an Array' do
        expect(converter.convert(derived_with_to_a)).to eq('[\'a\', 2]')
      end

      it 'formats a derived hash as a Runtime' do
        expect(converter.convert(hash)).to eq('{\'first\' => 1, \'second\' => 2}')
        expect(converter.convert(derived_hash)).to eq('{"first"=>1, "second"=>2}')
      end

      it 'formats a derived hash with #to_hash retuning plain Hash as a Hash' do
        expect(converter.convert(derived_with_to_hash, '%p')).to eq('{\'first\' => 1, \'second\' => 2}')
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PHashType::DEFAULT => "%k"}
      converter.convert({1 => 2}, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Hash type - expected one of the characters 'hasp'/)
    end
  end

  context 'when converting a runtime type' do
    [ :sym, (1..3), Time.now ].each do |value|
      it "the default string representation for #{value} is #to_s" do
        expect(converter.convert(value, :default)).to eq(value.to_s)
      end

      it "the '%q' string representation for #{value} is #inspect" do
        expect(converter.convert(value, '%q')).to eq(value.inspect)
      end

      it "the '%p' string representation for #{value} is quoted #to_s" do
        expect(converter.convert(value, '%p')).to eq("'#{value}'")
      end
    end

    it 'an unknown format raises an error' do
      expect { converter.convert(:sym, '%b') }.to raise_error("Illegal format 'b' specified for value of Runtime type - expected one of the characters 'spq'")
    end
  end

  context 'when converting regexp' do
    it 'the default string representation is "regexp"' do
      expect(converter.convert(/.*/, :default)).to eq('.*')
    end

    { "%s"   => '.*',
      "%6s"  => '    .*',
      "%.1s" => '.',
      "%-6s" => '.*    ',
      "%p"   => '/.*/',
      "%6p"  => '  /.*/',
      "%-6p" => '/.*/  ',
      "%.2p" => '/.',
      "%#s"  => "'.*'",
      "%#p"  => '/.*/'
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => fmt}
        expect(converter.convert(/.*/, string_formats)).to eq(result)
      end
    end

    context 'that contains flags' do
      it 'the format %s produces \'(?m-ix:[a-z]\s*)\' for expression /[a-z]\s*/m' do
        string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%s'}
        expect(converter.convert(/[a-z]\s*/m, string_formats)).to eq('(?m-ix:[a-z]\s*)')
      end

      it 'the format %p produces \'/(?m-ix:[a-z]\s*)/\' for expression /[a-z]\s*/m' do
        string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%p'}
        expect(converter.convert(/[a-z]\s*/m, string_formats)).to eq('/(?m-ix:[a-z]\s*)/')
      end

      it 'the format %p produces \'/foo\/bar/\' for expression /foo\/bar/' do
        string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%p'}
        expect(converter.convert(/foo\/bar/, string_formats)).to eq('/foo\/bar/')
      end

      context 'and slashes' do
        it 'the format %s produces \'(?m-ix:foo/bar)\' for expression /foo\/bar/m' do
          string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%s'}
          expect(converter.convert(/foo\/bar/m, string_formats)).to eq('(?m-ix:foo/bar)')
        end

        it 'the format %s produces \'(?m-ix:foo\/bar)\' for expression /foo\\\/bar/m' do
          string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%s'}
          expect(converter.convert(/foo\\\/bar/m, string_formats)).to eq('(?m-ix:foo\\\\/bar)')
        end

        it 'the format %p produces \'(?m-ix:foo\/bar)\' for expression /foo\/bar/m' do
          string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%p'}
          expect(converter.convert(/foo\/bar/m, string_formats)).to eq('/(?m-ix:foo\/bar)/')
        end

        it 'the format %p produces \'(?m-ix:foo\/bar)\' for expression /(?m-ix:foo\/bar)/' do
          string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => '%p'}
          expect(converter.convert(/(?m-ix:foo\/bar)/, string_formats)).to eq('/(?m-ix:foo\/bar)/')
        end
      end
    end

    it 'errors when format is not recognized' do
      expect do
      string_formats = { Puppet::Pops::Types::PRegexpType::DEFAULT => "%k"}
      converter.convert(/.*/, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Regexp type - expected one of the characters 'sp'/)
    end
  end

  context 'when converting binary' do
    let(:sample) { binary.from_binary_string('binary') }

    it 'the binary is converted to strict base64 string unquoted by default (same as %B)' do
      expect(converter.convert(sample, :default)).to eq("YmluYXJ5")
    end

    it 'the binary is converted using %p by default when contained in an array' do
      expect(converter.convert([sample], :default)).to eq("[Binary(\"YmluYXJ5\")]")
    end

    it '%B formats in base64 strict mode (same as default)' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%B'}
      expect(converter.convert(sample, string_formats)).to eq("YmluYXJ5")
    end

    it '%b formats in base64 relaxed mode, and adds newline' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%b'}
      expect(converter.convert(sample, string_formats)).to eq("YmluYXJ5\n")
    end

    it '%u formats in base64 urlsafe mode' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%u'}
      expect(converter.convert(binary.from_base64("++//"), string_formats)).to eq("--__")
    end

    it '%p formats with type name' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%p'}
      expect(converter.convert(sample, string_formats)).to eq("Binary(\"YmluYXJ5\")")
    end

    it '%#s formats as quoted string with escaped non printable bytes' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%#s'}
      expect(converter.convert(binary.from_base64("apa="), string_formats)).to eq("\"j\\x96\"")
    end

    it '%s formats as unquoted string with valid UTF-8 chars' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%s'}
      # womans hat emoji is E318, a three byte UTF-8 char EE 8C 98
      expect(converter.convert(binary.from_binary_string("\xEE\x8C\x98"), string_formats)).to eq("\uE318")
    end

    it '%s errors if given non UTF-8 bytes' do
      string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => '%s'}
      expect {
        converter.convert(binary.from_base64("apa="), string_formats)
      }.to raise_error(Encoding::UndefinedConversionError)
    end

    { "%s"    => 'binary',
      "%#s"   => '"binary"',
      "%8s"   => '  binary',
      "%.2s"  => 'bi',
      "%-8s"  => 'binary  ',
      "%p"    => 'Binary("YmluYXJ5")',
      "%10p"  => 'Binary("  YmluYXJ5")',
      "%-10p" => 'Binary("YmluYXJ5  ")',
      "%.2p"  => 'Binary("Ym")',
      "%b"    => "YmluYXJ5\n",
      "%11b"  => "  YmluYXJ5\n",
      "%-11b" => "YmluYXJ5\n  ",
      "%.2b"  => "Ym",
      "%B"    => "YmluYXJ5",
      "%11B"  => "   YmluYXJ5",
      "%-11B" => "YmluYXJ5   ",
      "%.2B"  => "Ym",
      "%u"    => "YmluYXJ5",
      "%11u"  => "   YmluYXJ5",
      "%-11u" => "YmluYXJ5   ",
      "%.2u"  => "Ym",
      "%t"    => 'Binary',
      "%#t"   => '"Binary"',
      "%8t"   => '  Binary',
      "%-8t"  => 'Binary  ',
      "%.3t"  => 'Bin',
      "%T"    => 'BINARY',
      "%#T"   => '"BINARY"',
      "%8T"   => '  BINARY',
      "%-8T"  => 'BINARY  ',
      "%.3T"  => 'BIN',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PBinaryType::DEFAULT => fmt}
        expect(converter.convert(sample, string_formats)).to eq(result)
      end
    end
  end

  context 'when converting iterator' do
    it 'the iterator is transformed to an array and formatted using array rules' do
      itor = Puppet::Pops::Types::Iterator.new(Puppet::Pops::Types::PIntegerType::DEFAULT, [1,2,3]).reverse_each
      expect(converter.convert(itor, :default)).to eq('[3, 2, 1]')
    end
  end

  context 'when converting type' do
    it 'the default string representation of a type is its programmatic string form' do
      expect(converter.convert(factory.integer, :default)).to eq('Integer')
    end

    { "%s"  => 'Integer',
      "%p"  => 'Integer',
      "%#s" => '"Integer"',
      "%#p" => 'Integer',
    }.each do |fmt, result |
      it "the format #{fmt} produces #{result}" do
        string_formats = { Puppet::Pops::Types::PTypeType::DEFAULT => fmt}
        expect(converter.convert(factory.integer, string_formats)).to eq(result)
      end
    end

    it 'errors when format is not recognized' do
      expect do
        string_formats = { Puppet::Pops::Types::PTypeType::DEFAULT => "%k"}
        converter.convert(factory.integer, string_formats)
      end.to raise_error(/Illegal format 'k' specified for value of Type type - expected one of the characters 'sp'/)
    end
  end

  it "allows format to be directly given (instead of as a type=> format hash)" do
    expect(converter.convert('hello', '%5.1s')).to eq('    h')
  end

  it 'an explicit format for a type will override more specific defaults' do
    expect(converter.convert({ 'x' => 'X' }, { Puppet::Pops::Types::PCollectionType::DEFAULT => '%#p' })).to eq("{\n  'x' => 'X'\n}")
  end
end
