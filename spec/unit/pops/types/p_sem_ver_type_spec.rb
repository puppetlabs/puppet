require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'Semantic Versions' do
  include PuppetSpec::Compiler

  context 'the SemVer type' do
    it 'is normalized in a Variant' do
      t = TypeFactory.variant(TypeFactory.sem_ver('>=1.0.0 <2.0.0'), TypeFactory.sem_ver('>=1.5.0 <4.0.0')).normalize
      expect(t).to be_a(PSemVerType)
      expect(t).to eql(TypeFactory.sem_ver('>=1.0.0 <4.0.0'))
    end

    context 'convert method' do
      it 'returns nil on a nil argument' do
        expect(PSemVerType.convert(nil)).to be_nil
      end

      it 'returns its argument when the argument is a version' do
        v = SemanticPuppet::Version.new(1,0,0)
        expect(PSemVerType.convert(v)).to equal(v)
      end

      it 'converts a valid version string argument to a version' do
        v = SemanticPuppet::Version.new(1,0,0)
        expect(PSemVerType.convert('1.0.0')).to eq(v)
      end

      it 'raises an error string that does not represent a valid version' do
        expect{PSemVerType.convert('1-3')}.to raise_error(ArgumentError)
      end
    end
  end

  context 'the SemVerRange type' do
     context 'convert method' do
      it 'returns nil on a nil argument' do
        expect(PSemVerRangeType.convert(nil)).to be_nil
      end

      it 'returns its argument when the argument is a version range' do
        vr = SemanticPuppet::VersionRange.parse('1.x')
        expect(PSemVerRangeType.convert(vr)).to equal(vr)
      end

      it 'converts a valid version string argument to a version range' do
        vr = SemanticPuppet::VersionRange.parse('1.x')
        expect(PSemVerRangeType.convert('1.x')).to eq(vr)
      end

      it 'raises an error string that does not represent a valid version range' do
        expect{PSemVerRangeType.convert('x3')}.to raise_error(ArgumentError)
      end
    end
  end

  context 'when used in Puppet expressions' do

    context 'the SemVer type' do
      it 'can have multiple range arguments' do
        code = <<-CODE
          $t = SemVer[SemVerRange('>=1.0.0 <2.0.0'), SemVerRange('>=3.0.0 <4.0.0')]
          notice(SemVer('1.2.3') =~ $t)
          notice(SemVer('2.3.4') =~ $t)
          notice(SemVer('3.4.5') =~ $t)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true', 'false', 'true'])
      end

      it 'can have multiple range arguments in string form' do
        code = <<-CODE
          $t = SemVer['>=1.0.0 <2.0.0', '>=3.0.0 <4.0.0']
          notice(SemVer('1.2.3') =~ $t)
          notice(SemVer('2.3.4') =~ $t)
          notice(SemVer('3.4.5') =~ $t)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true', 'false', 'true'])
      end

      it 'range arguments are normalized' do
        code = <<-CODE
          notice(SemVer['>=1.0.0 <2.0.0', '>=1.5.0 <4.0.0'] == SemVer['>=1.0.0 <4.0.0'])
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end

      it 'is assignable to a type containing ranges with a merged range that is assignable but individual ranges are not' do
        code = <<-CODE
          $x = SemVer['>=1.0.0 <2.0.0', '>=1.5.0 <3.0.0']
          $y = SemVer['>=1.2.0 <2.8.0']
          notice($y < $x)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
     end
    end

    context 'the SemVerRange type' do
      it 'a range is an instance of the type' do
        code = <<-CODE
          notice(SemVerRange('3.0.0 - 4.0.0') =~ SemVerRange)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end
    end

    context 'a SemVer instance' do
      it 'can be created from a String' do
        code = <<-CODE
          $x = SemVer('1.2.3')
          notice(assert_type(SemVer, $x))
        CODE
        expect(eval_and_collect_notices(code)).to eql(['1.2.3'])
      end

      it 'can be compared to another instance for equality' do
        code = <<-CODE
          $x = SemVer('1.2.3')
          $y = SemVer('1.2.3')
          notice($x == $y)
          notice($x != $y)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true', 'false'])
      end

      it 'can be compared to another instance for magnitude' do
        code = <<-CODE
          $x = SemVer('1.1.1')
          $y = SemVer('1.2.3')
          notice($x < $y)
          notice($x <= $y)
          notice($x > $y)
          notice($x >= $y)
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true', 'true', 'false', 'false'])
      end

      it 'can be matched against a version range' do
        code = <<-CODE
          $v = SemVer('1.1.1')
          notice($v =~ SemVerRange('>1.0.0'))
          notice($v =~ SemVerRange('>1.1.1'))
          notice($v =~ SemVerRange('>=1.1.1'))
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true', 'false', 'true'])
      end

      it 'can be matched against a SemVerRange in case expression' do
        code = <<-CODE
          case SemVer('1.1.1') {
            SemVerRange('>1.1.1'): {
              notice('high')
            }
            SemVerRange('>1.0.0'): {
              notice('mid')
            }
            default: {
              notice('low')
            }
          }
        CODE
        expect(eval_and_collect_notices(code)).to eql(['mid'])
      end

      it 'can be matched against a SemVer in case expression' do
        code = <<-CODE
          case SemVer('1.1.1') {
            SemVer('1.1.0'): {
              notice('high')
            }
            SemVer('1.1.1'): {
              notice('mid')
            }
            default: {
              notice('low')
            }
          }
        CODE
        expect(eval_and_collect_notices(code)).to eql(['mid'])
      end

      it "can be matched against a versions in 'in' expression" do
        code = <<-CODE
          notice(SemVer('1.1.1') in [SemVer('1.0.0'), SemVer('1.1.1'), SemVer('2.3.4')])
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end

      it "can be matched against a VersionRange using an 'in' expression" do
        code = <<-CODE
          notice(SemVer('1.1.1') in SemVerRange('>1.0.0'))
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end

      it "can be matched against multiple VersionRanges using an 'in' expression" do
        code = <<-CODE
          notice(SemVer('1.1.1') in [SemVerRange('>=1.0.0 <1.0.2'), SemVerRange('>=1.1.0 <1.1.2')])
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end
    end

    context 'a String representing a SemVer' do
      it 'can be matched against a version range' do
        code = <<-CODE
          $v = '1.1.1'
          notice($v =~ SemVerRange('>1.0.0'))
          notice($v =~ SemVerRange('>1.1.1'))
          notice($v =~ SemVerRange('>=1.1.1'))
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true', 'false', 'true'])
      end

      it 'can be matched against a SemVerRange in case expression' do
        code = <<-CODE
          case '1.1.1' {
            SemVerRange('>1.1.1'): {
              notice('high')
            }
            SemVerRange('>1.0.0'): {
              notice('mid')
            }
            default: {
              notice('low')
            }
          }
        CODE
        expect(eval_and_collect_notices(code)).to eql(['mid'])
      end

      it 'can be matched against a SemVer in case expression' do
        code = <<-CODE
          case '1.1.1' {
            SemVer('1.1.0'): {
              notice('high')
            }
            SemVer('1.1.1'): {
              notice('mid')
            }
            default: {
              notice('low')
            }
          }
        CODE
        expect(eval_and_collect_notices(code)).to eql(['mid'])
      end

      it "can be matched against a VersionRange using an 'in' expression" do
        code = <<-CODE
          notice('1.1.1' in SemVerRange('>1.0.0'))
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end

      it "can be matched against multiple VersionRanges using an 'in' expression" do
        code = <<-CODE
          notice('1.1.1' in [SemVerRange('>=1.0.0 <1.0.2'), SemVerRange('>=1.1.0 <1.1.2')])
        CODE
        expect(eval_and_collect_notices(code)).to eql(['true'])
      end
    end

    context 'matching SemVer' do
      suitability = {
        [ '1.2.3',         '1.2.2' ] => false,
        [ '>=1.2.3',       '1.2.2' ] => false,
        [ '<=1.2.3',       '1.2.2' ] => true,
        [ '1.2.3 - 1.2.4', '1.2.2' ] => false,
        [ '~1.2.3',        '1.2.2' ] => false,
        [ '~1.2',          '1.2.2' ] => true,
        [ '~1',            '1.2.2' ] => true,
        [ '1.2.x',         '1.2.2' ] => true,
        [ '1.x',           '1.2.2' ] => true,

        [ '1.2.3-alpha',   '1.2.3-alpha' ] => true,
        [ '>=1.2.3-alpha', '1.2.3-alpha' ] => true,
        [ '<=1.2.3-alpha', '1.2.3-alpha' ] => true,
        [ '<=1.2.3-alpha', '1.2.3-a'     ] => true,
        [ '>1.2.3-alpha',  '1.2.3-alpha' ] => false,
        [ '>1.2.3-a',      '1.2.3-alpha' ] => true,
        [ '<1.2.3-alpha',  '1.2.3-alpha' ] => false,
        [ '<1.2.3-alpha',  '1.2.3-a'     ] => true,
        [ '1.2.3-alpha - 1.2.4', '1.2.3-alpha' ] => true,
        [ '1.2.3 - 1.2.4-alpha', '1.2.4-alpha' ] => true,
        [ '1.2.3 - 1.2.4', '1.2.5-alpha' ] => false,
        [ '~1.2.3-alhpa',        '1.2.3-alpha' ] => true,
        [ '~1.2.3-alpha',        '1.3.0-alpha' ] => false,

        [ '1.2.3',         '1.2.3' ] => true,
        [ '>=1.2.3',       '1.2.3' ] => true,
        [ '<=1.2.3',       '1.2.3' ] => true,
        [ '1.2.3 - 1.2.4', '1.2.3' ] => true,
        [ '~1.2.3',        '1.2.3' ] => true,
        [ '~1.2',          '1.2.3' ] => true,
        [ '~1',            '1.2.3' ] => true,
        [ '1.2.x',         '1.2.3' ] => true,
        [ '1.x',           '1.2.3' ] => true,

        [ '1.2.3',         '1.2.4' ] => false,
        [ '>=1.2.3',       '1.2.4' ] => true,
        [ '<=1.2.3',       '1.2.4' ] => false,
        [ '1.2.3 - 1.2.4', '1.2.4' ] => true,
#        [ '~1.2.3',        '1.2.4' ] => true, Awaits fix for PUP-6242
        [ '~1.2',          '1.2.4' ] => true,
        [ '~1',            '1.2.4' ] => true,
        [ '1.2.x',         '1.2.4' ] => true,
        [ '1.x',           '1.2.4' ] => true,
      }
      suitability.each do |arguments, expected|
        it "'#{arguments[1]}' against SemVerRange '#{arguments[0]}', yields #{expected}" do
          code = "notice(SemVer('#{arguments[1]}') =~ SemVerRange('#{arguments[0]}'))"
          expect(eval_and_collect_notices(code)).to eql([expected.to_s])
        end
      end
    end
  end
end
end
end
