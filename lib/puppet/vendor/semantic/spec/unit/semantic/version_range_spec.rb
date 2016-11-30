require 'spec_helper'
require 'semantic/version'

describe Semantic::VersionRange do

  describe '.parse' do
    def self.test_range(range_list, str, includes, excludes)
      Array(range_list).each do |expr|
        example "#{expr.inspect} stringifies as #{str}" do
          range = Semantic::VersionRange.parse(expr)
          expect(range.to_s).to eql str
        end

        includes.each do |vstring|
          example "#{expr.inspect} includes #{vstring}" do
            range = Semantic::VersionRange.parse(expr)
            expect(range).to include(Semantic::Version.parse(vstring))
          end

          example "parse(#{expr.inspect}).to_s includes #{vstring}" do
            range = Semantic::VersionRange.parse(expr)
            range = Semantic::VersionRange.parse(range.to_s)
            expect(range).to include(Semantic::Version.parse(vstring))
          end
        end

        excludes.each do |vstring|
          example "#{expr.inspect} excludes #{vstring}" do
            range = Semantic::VersionRange.parse(expr)
            expect(range).to_not include(Semantic::Version.parse(vstring))
          end

          example "parse(#{expr.inspect}).to_s excludes #{vstring}" do
            range = Semantic::VersionRange.parse(expr)
            range = Semantic::VersionRange.parse(range.to_s)
            expect(range).to_not include(Semantic::Version.parse(vstring))
          end
        end
      end
    end

    context 'loose version expressions' do
      expressions = {
        [ '1.2.3-alpha' ] => {
          :to_str   => '1.2.3-alpha',
          :includes => [ '1.2.3-alpha'  ],
          :excludes => [ '1.2.3-999', '1.2.3-beta' ],
        },
        [ '1.2.3' ] => {
          :to_str   => '1.2.3',
          :includes => [ '1.2.3-alpha', '1.2.3' ],
          :excludes => [ '1.2.2', '1.2.4-alpha' ],
        },
        [ '1.2', '1.2.x', '1.2.X' ] => {
          :to_str   => '1.2.x',
          :includes => [ '1.2.0-alpha', '1.2.0', '1.2.999' ],
          :excludes => [ '1.1.999', '1.3.0-0' ],
        },
        [ '1', '1.x', '1.X' ] => {
          :to_str   => '1.x',
          :includes => [ '1.0.0-alpha', '1.999.0' ],
          :excludes => [ '0.999.999', '2.0.0-0' ],
        },
      }

      expressions.each do |range, vs|
        test_range(range, vs[:to_str], vs[:includes], vs[:excludes])
      end
    end

    context 'open-ended expressions' do
      expressions = {
        [ '>1.2.3', '> 1.2.3' ] => {
          :to_str   => '>=1.2.4',
          :includes => [ '1.2.4-0', '999.0.0' ],
          :excludes => [ '1.2.3' ],
        },
        [ '>1.2.3-alpha', '> 1.2.3-alpha' ] => {
          :to_str   => '>1.2.3-alpha',
          :includes => [ '1.2.3-alpha.0', '1.2.3-alpha0', '999.0.0' ],
          :excludes => [ '1.2.3-alpha' ],
        },

        [ '>=1.2.3', '>= 1.2.3' ] => {
          :to_str   => '>=1.2.3',
          :includes => [ '1.2.3-0', '999.0.0' ],
          :excludes => [ '1.2.2' ],
        },
        [ '>=1.2.3-alpha', '>= 1.2.3-alpha' ] => {
          :to_str   => '>=1.2.3-alpha',
          :includes => [ '1.2.3-alpha', '1.2.3-alpha0', '999.0.0' ],
          :excludes => [ '1.2.3-alph' ],
        },

        [ '<1.2.3', '< 1.2.3' ] => {
          :to_str   => '<1.2.3',
          :includes => [ '0.0.0-0', '1.2.2' ],
          :excludes => [ '1.2.3-0', '2.0.0' ],
        },
        [ '<1.2.3-alpha', '< 1.2.3-alpha' ] => {
          :to_str   => '<1.2.3-alpha',
          :includes => [ '0.0.0-0', '1.2.3-alph' ],
          :excludes => [ '1.2.3-alpha', '2.0.0' ],
        },

        [ '<=1.2.3', '<= 1.2.3' ] => {
          :to_str   => '<1.2.4',
          :includes => [ '0.0.0-0', '1.2.3' ],
          :excludes => [ '1.2.4-0' ],
        },
        [ '<=1.2.3-alpha', '<= 1.2.3-alpha' ] => {
          :to_str   => '<=1.2.3-alpha',
          :includes => [ '0.0.0-0', '1.2.3-alpha' ],
          :excludes => [ '1.2.3-alpha0', '1.2.3-alpha.0', '1.2.3-alpha'.next ],
        },
      }

      expressions.each do |range, vs|
        test_range(range, vs[:to_str], vs[:includes], vs[:excludes])
      end
    end

    context '"reasonably close" expressions' do
      expressions = {
        [ '~ 1', '~1' ] => {
          :to_str   => '1.x',
          :includes => [ '1.0.0-0', '1.999.999' ],
          :excludes => [ '0.999.999', '2.0.0-0' ],
        },
        [ '~ 1.2', '~1.2' ] => {
          :to_str   => '1.2.x',
          :includes => [ '1.2.0-0', '1.2.999' ],
          :excludes => [ '1.1.999', '1.3.0-0' ],
        },
        [ '~ 1.2.3', '~1.2.3' ] => {
          :to_str   => '1.2.3',
          :includes => [ '1.2.3-0', '1.2.3' ],
          :excludes => [ '1.2.2', '1.2.4-0' ],
        },
        [ '~ 1.2.3-alpha', '~1.2.3-alpha' ] => {
          :to_str   => '>=1.2.3-alpha <1.2.4',
          :includes => [ '1.2.3-alpha', '1.2.3' ],
          :excludes => [ '1.2.3-alph', '1.2.4-0' ],
        },
      }

      expressions.each do |range, vs|
        test_range(range, vs[:to_str], vs[:includes], vs[:excludes])
      end
    end

    context 'inclusive range expressions' do
      expressions = {
        '1.2.3 - 1.3.4' => {
          :to_str   => '>=1.2.3 <1.3.5',
          :includes => [ '1.2.3-0', '1.3.4' ],
          :excludes => [ '1.2.2', '1.3.5-0' ],
        },
        '1.2.3 - 1.3.4-alpha' => {
          :to_str   => '>=1.2.3 <=1.3.4-alpha',
          :includes => [ '1.2.3-0', '1.3.4-alpha' ],
          :excludes => [ '1.2.2', '1.3.4-alpha0', '1.3.5' ],
        },

        '1.2.3-alpha - 1.3.4' => {
          :to_str   => '>=1.2.3-alpha <1.3.5',
          :includes => [ '1.2.3-alpha', '1.3.4' ],
          :excludes => [ '1.2.3-alph', '1.3.5-0' ],
        },
        '1.2.3-alpha - 1.3.4-alpha' => {
          :to_str   => '>=1.2.3-alpha <=1.3.4-alpha',
          :includes => [ '1.2.3-alpha', '1.3.4-alpha' ],
          :excludes => [ '1.2.3-alph', '1.3.4-alpha0', '1.3.5' ],
        },
      }

      expressions.each do |range, vs|
        test_range(range, vs[:to_str], vs[:includes], vs[:excludes])
      end
    end

    context 'unioned expressions' do
      expressions = {
        [ '1.2 <1.2.5' ] => {
          :to_str   => '>=1.2.0 <1.2.5',
          :includes => [ '1.2.0-0', '1.2.4' ],
          :excludes => [ '1.1.999', '1.2.5-0', '1.9.0' ],
        },
        [ '1 <=1.2.5' ] => {
          :to_str   => '>=1.0.0 <1.2.6',
          :includes => [ '1.0.0-0', '1.2.5' ],
          :excludes => [ '0.999.999', '1.2.6-0', '1.9.0' ],
        },
        [ '>1.0.0 >2.0.0 >=3.0.0 <5.0.0' ] => {
          :to_str   => '>=3.0.0 <5.0.0',
          :includes => [ '3.0.0-0', '4.999.999' ],
          :excludes => [ '2.999.999', '5.0.0-0' ],
        },
        [ '<1.0.0 >2.0.0' ] => {
          :to_str   => '<0.0.0',
          :includes => [  ],
          :excludes => [ '0.0.0-0' ],
        },
      }

      expressions.each do |range, vs|
        test_range(range, vs[:to_str], vs[:includes], vs[:excludes])
      end
    end

    context 'invalid expressions' do
      example 'raise an appropriate exception' do
        ex = [ ArgumentError, 'Unparsable version range: "invalid"' ]
        expect { Semantic::VersionRange.parse('invalid') }.to raise_error(*ex)
      end
    end
  end

  describe '#intersection' do
    def self.v(num)
      Semantic::Version.parse("#{num}.0.0")
    end

    def self.range(x, y, ex = false)
      Semantic::VersionRange.new(v(x), v(y), ex)
    end

    EMPTY_RANGE = Semantic::VersionRange::EMPTY_RANGE

    tests = {
      # This falls entirely before the target range
      range(1, 4) => [ EMPTY_RANGE ],

      # This falls entirely after the target range
      range(11, 15) => [ EMPTY_RANGE ],

      # This overlaps the beginning of the target range
      range(1, 6) => [ range(5, 6) ],

      # This overlaps the end of the target range
      range(9, 15) => [ range(9, 10), range(9, 10, true) ],

      # This shares the first value of the target range
      range(1, 5) => [ range(5, 5) ],

      # This shares the last value of the target range
      range(10, 15)  => [ range(10, 10), EMPTY_RANGE ],

      # This shares both values with the target range
      range(5, 10) => [ range(5, 10), range(5, 10, true) ],

      # This is a superset of the target range
      range(4, 11) => [ range(5, 10), range(5, 10, true) ],

      # This is a subset of the target range
      range(6, 9) => [ range(6, 9) ],

      # This shares the first value of the target range, but excludes it
      range(1, 5, true)   => [ EMPTY_RANGE ],

      # This overlaps the beginning of the target range, with an excluded end
      range(1, 7, true)   => [ range(5, 7, true) ],

      # This shares both values with the target range, and excludes the end
      range(5, 10, true)  => [ range(5, 10, true) ],
    }

    inclusive = range(5, 10)
    context "between #{inclusive} &" do
      tests.each do |subject, result|
        result = result.first

        example subject do
          expect(inclusive & subject).to eql(result)
        end
      end
    end

    exclusive = range(5, 10, true)
    context "between #{exclusive} &" do
      tests.each do |subject, result|
        result = result.last

        example subject do
          expect(exclusive & subject).to eql(result)
        end
      end
    end

    context 'is commutative' do
      tests.each do |subject, _|
        example "between #{inclusive} & #{subject}" do
          expect(inclusive & subject).to eql(subject & inclusive)
        end
        example "between #{exclusive} & #{subject}" do
          expect(exclusive & subject).to eql(subject & exclusive)
        end
      end
    end

    it 'cannot intersect with non-VersionRanges' do
      msg = "value must be a Semantic::VersionRange"
      expect { inclusive.intersection(1..2) }.to raise_error(msg)
    end
  end

end
