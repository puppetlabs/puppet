require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the getvar function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'returns undef value' do
    it 'when result is undef due to missing variable' do
      expect( evaluate(source: "getvar('x')")).to be_nil
    end

    it 'when result is undef due to resolved undef variable value' do
      expect( evaluate(source: "$x = undef; getvar('x')")).to be_nil
    end

    it 'when result is undef due to navigation into undef' do
      expect( evaluate(source: "$x = undef; getvar('x.0')")).to be_nil
    end
  end

  context 'returns default value' do
    it 'when result is undef due to missing variable' do
      expect( evaluate(source: "getvar('x', 'ok')")).to eql('ok')
    end

    it 'when result is undef due to resolved undef variable value' do
      expect( evaluate(source: "$x = undef; getvar('x', 'ok')")).to eql('ok')
    end

    it 'when result is undef due to navigation into undef' do
      expect( evaluate(source: "$x = undef; getvar('x.0', 'ok')")).to eql('ok')
    end
  end

  it 'returns value of $variable if dotted navigation is not present' do
    expect(evaluate(source: "$x = 'testing'; getvar('x')")).to eql('testing')
  end

  it 'returns value of fully qualified $namespace::variable if dotted navigation is not present' do
    expect(evaluate(
             code:
               "class testing::nested { $x = ['ok'] } include 'testing::nested'",
             source:
               "getvar('testing::nested::x.0')"
           )).to eql('ok')
  end

  it 'navigates into $variable if given dot syntax after variable name' do
    expect(
      evaluate(
        variables: {'x'=> ['nope', ['ok']]},
        source: "getvar('x.1.0')"
      )
    ).to eql('ok')
  end

  it 'can navigate a key with . when it is quoted' do
    expect(
      evaluate(
        variables: {'x' => {'a.b' => ['nope', ['ok']]}},
        source: "getvar('x.\"a.b\".1.0')"
      )
    ).to eql('ok')
  end

  it 'an error is raised when navigating with string key into an array' do
    expect {
      evaluate(source: "$x =['nope', ['ok']]; getvar('x.1.blue')")
    }.to raise_error(/The given data requires an Integer index/)
  end

  ['X', ':::x', 'x:::x', 'x-x', '_x::x', 'x::', '1'].each do |var_string|
    it "an error pointing out that varible is invalid is raised for variable '#{var_string}'" do
      expect {
        evaluate(source: "getvar(\"#{var_string}.1.blue\")")
      }.to raise_error(/The given string does not start with a valid variable name/)
    end
  end

  it 'calls a given block with EXPECTED_INTEGER_INDEX if navigating into array with string' do
    expect(evaluate(
             source:
               "$x = ['nope', ['ok']]; getvar('x.1.blue') |$error| {
                 if $error.issue_code =~ /^EXPECTED_INTEGER_INDEX$/ {'ok'} else { 'nope'}
                }"
           )).to eql('ok')
  end

  it 'calls a given block with EXPECTED_COLLECTION if navigating into something not Undef or Collection' do
    expect(evaluate(
             source:
               "$x = ['nope', /nah/]; getvar('x.1.blue') |$error| {
                  if $error.issue_code =~ /^EXPECTED_COLLECTION$/ {'ok'} else { 'nope'}
                }"
           )).to eql('ok')
  end

  context 'it does not pick the default value when undef is returned by error handling block' do
    it 'for "expected integer" case' do
      expect(evaluate(
               source: "$x = ['nope', ['ok']]; getvar('x.1.blue', 'nope') |$msg| { undef }"
             )).to be_nil
    end

    it 'for "expected collection" case' do
      expect(evaluate(
               source: "$x = ['nope', /nah/]; getvar('x.1.blue') |$msg| { undef }"
             )).to be_nil
    end
  end

  it 'does not call a given block if navigation string has syntax error' do
    expect {evaluate(
      source: "$x = ['nope', /nah/]; getvar('x.1....') |$msg| { fail('so sad') }"
    )}.to raise_error(/Syntax error/)
  end

end
