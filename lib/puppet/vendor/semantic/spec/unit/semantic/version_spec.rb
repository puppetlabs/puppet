require 'spec_helper'
require 'semantic/version'

describe Semantic::Version do

  def subject(str)
    Semantic::Version.parse(str)
  end

  describe '.parse' do

    context 'Spec v2.0.0' do
      context 'Section 2' do
        # A normal version number MUST take the form X.Y.Z where X, Y, and Z are
        # non-negative integers, and MUST NOT contain leading zeroes. X is the
        # major version, Y is the minor version, and Z is the patch version.
        # Each element MUST increase numerically.
        # For instance: 1.9.0 -> 1.10.0 -> 1.11.0.

        let(:must_begin_with_digits) do
          'Version numbers MUST begin with three dot-separated numbers'
        end

        let(:no_leading_zeroes) do
          'Version numbers MUST NOT contain leading zeroes'
        end

        it 'rejects versions that contain too few parts' do
          expect { subject('1.2') }.to raise_error(must_begin_with_digits)
        end

        it 'rejects versions that contain too many parts' do
          expect { subject('1.2.3.4') }.to raise_error(must_begin_with_digits)
        end

        it 'rejects versions that contain non-integers' do
          expect { subject('x.2.3') }.to raise_error(must_begin_with_digits)
          expect { subject('1.y.3') }.to raise_error(must_begin_with_digits)
          expect { subject('1.2.z') }.to raise_error(must_begin_with_digits)
        end

        it 'rejects versions that contain negative integers' do
          expect { subject('-1.2.3') }.to raise_error(must_begin_with_digits)
          expect { subject('1.-2.3') }.to raise_error(must_begin_with_digits)
          expect { subject('1.2.-3') }.to raise_error(must_begin_with_digits)
        end

        it 'rejects version numbers containing leading zeroes' do
          expect { subject('01.2.3') }.to raise_error(no_leading_zeroes)
          expect { subject('1.02.3') }.to raise_error(no_leading_zeroes)
          expect { subject('1.2.03') }.to raise_error(no_leading_zeroes)
        end

        it 'permits zeroes in version number parts' do
          expect { subject('0.2.3') }.to_not raise_error
          expect { subject('1.0.3') }.to_not raise_error
          expect { subject('1.2.0') }.to_not raise_error
        end

        context 'examples' do
          example '1.9.0' do
            version = subject('1.9.0')
            expect(version.major).to eql 1
            expect(version.minor).to eql 9
            expect(version.patch).to eql 0
          end

          example '1.10.0' do
            version = subject('1.10.0')
            expect(version.major).to eql 1
            expect(version.minor).to eql 10
            expect(version.patch).to eql 0
          end

          example '1.11.0' do
            version = subject('1.11.0')
            expect(version.major).to eql 1
            expect(version.minor).to eql 11
            expect(version.patch).to eql 0
          end
        end
      end

      context 'Section 9' do
        # A pre-release version MAY be denoted by appending a hyphen and a
        # series of dot separated identifiers immediately following the patch
        # version. Identifiers MUST comprise only ASCII alphanumerics and
        # hyphen [0-9A-Za-z-]. Identifiers MUST NOT be empty. Numeric
        # identifiers MUST NOT include leading zeroes. Pre-release versions
        # have a lower precedence than the associated normal version. A
        # pre-release version indicates that the version is unstable and
        # might not satisfy the intended compatibility requirements as denoted
        # by its associated normal version.
        # Examples: 1.0.0-alpha, 1.0.0-alpha.1, 1.0.0-0.3.7, 1.0.0-x.7.z.92.

        let(:restricted_charset) do
          'Prerelease identifiers MUST use only ASCII alphanumerics and hyphens'
        end

        let(:must_not_be_empty) do
          'Prerelease identifiers MUST NOT be empty'
        end

        let(:no_leading_zeroes) do
          'Prerelease identifiers MUST NOT contain leading zeroes'
        end

        it 'rejects prerelease identifiers with non-alphanumerics' do
          expect { subject('1.2.3-$100') }.to raise_error(restricted_charset)
          expect { subject('1.2.3-rc.1@me') }.to raise_error(restricted_charset)
        end

        it 'rejects empty prerelease versions' do
          expect { subject('1.2.3-') }.to raise_error(must_not_be_empty)
        end

        it 'rejects empty prerelease version identifiers' do
          expect { subject('1.2.3-.rc1') }.to raise_error(must_not_be_empty)
          expect { subject('1.2.3-rc1.') }.to raise_error(must_not_be_empty)
          expect { subject('1.2.3-rc..1') }.to raise_error(must_not_be_empty)
        end

        it 'rejects numeric prerelease identifiers with leading zeroes' do
          expect { subject('1.2.3-01') }.to raise_error(no_leading_zeroes)
          expect { subject('1.2.3-rc.01') }.to raise_error(no_leading_zeroes)
        end

        it 'permits numeric prerelease identifiers of zero' do
          expect { subject('1.2.3-0') }.to_not raise_error
          expect { subject('1.2.3-rc.0') }.to_not raise_error
        end

        it 'permits non-numeric prerelease identifiers with leading zeroes' do
          expect { subject('1.2.3-0xDEADBEEF') }.to_not raise_error
          expect { subject('1.2.3-rc.0x10c') }.to_not raise_error
        end

        context 'examples' do
          example '1.0.0-alpha' do
            version = subject('1.0.0-alpha')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'alpha'
          end

          example '1.0.0-alpha.1' do
            version = subject('1.0.0-alpha.1')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'alpha.1'
          end

          example '1.0.0-0.3.7' do
            version = subject('1.0.0-0.3.7')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql '0.3.7'
          end

          example '1.0.0-x.7.z.92' do
            version = subject('1.0.0-x.7.z.92')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'x.7.z.92'
          end
        end
      end

      context 'Section 10' do
        # Build metadata MAY be denoted by appending a plus sign and a series
        # of dot separated identifiers immediately following the patch or
        # pre-release version. Identifiers MUST comprise only ASCII
        # alphanumerics and hyphen [0-9A-Za-z-]. Identifiers MUST NOT be empty.
        # Build metadata SHOULD be ignored when determining version precedence.
        # Thus two versions that differ only in the build metadata, have the
        # same precedence.
        # Examples: 1.0.0-alpha+001, 1.0.0+20130313144700,
        # 1.0.0-beta+exp.sha.5114f85.


        let(:restricted_charset) do
          'Build identifiers MUST use only ASCII alphanumerics and hyphens'
        end

        let(:must_not_be_empty) do
          'Build identifiers MUST NOT be empty'
        end

        it 'rejects build identifiers with non-alphanumerics' do
          expect { subject('1.2.3+$100') }.to raise_error(restricted_charset)
          expect { subject('1.2.3+rc.1@me') }.to raise_error(restricted_charset)
        end

        it 'rejects empty build metadata' do
          expect { subject('1.2.3+') }.to raise_error(must_not_be_empty)
        end

        it 'rejects empty build identifiers' do
          expect { subject('1.2.3+.rc1') }.to raise_error(must_not_be_empty)
          expect { subject('1.2.3+rc1.') }.to raise_error(must_not_be_empty)
          expect { subject('1.2.3+rc..1') }.to raise_error(must_not_be_empty)
        end

        it 'permits numeric build identifiers with leading zeroes' do
          expect { subject('1.2.3+01') }.to_not raise_error
          expect { subject('1.2.3+rc.01') }.to_not raise_error
        end

        it 'permits numeric build identifiers of zero' do
          expect { subject('1.2.3+0') }.to_not raise_error
          expect { subject('1.2.3+rc.0') }.to_not raise_error
        end

        it 'permits non-numeric build identifiers with leading zeroes' do
          expect { subject('1.2.3+0xDEADBEEF') }.to_not raise_error
          expect { subject('1.2.3+rc.0x10c') }.to_not raise_error
        end

        context 'examples' do
          example '1.0.0-alpha+001' do
            version = subject('1.0.0-alpha+001')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'alpha'
            expect(version.build).to eql '001'
          end

          example '1.0.0+20130313144700' do
            version = subject('1.0.0+20130313144700')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql nil
            expect(version.build).to eql '20130313144700'
          end

          example '1.0.0-beta+exp.sha.5114f85' do
            version = subject('1.0.0-beta+exp.sha.5114f85')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'beta'
            expect(version.build).to eql 'exp.sha.5114f85'
          end
        end
      end
    end

    context 'Spec v1.0.0' do
      context 'Section 2' do
        # A normal version number MUST take the form X.Y.Z where X, Y, and Z
        # are integers. X is the major version, Y is the minor version, and Z
        # is the patch version. Each element MUST increase numerically by
        # increments of one.
        # For instance: 1.9.0 -> 1.10.0 -> 1.11.0

        let(:must_begin_with_digits) do
          'Version numbers MUST begin with three dot-separated numbers'
        end

        let(:no_leading_zeroes) do
          'Version numbers MUST NOT contain leading zeroes'
        end

        it 'rejects versions that contain too few parts' do
          expect { subject('1.2') }.to raise_error(must_begin_with_digits)
        end

        it 'rejects versions that contain too many parts' do
          expect { subject('1.2.3.4') }.to raise_error(must_begin_with_digits)
        end

        it 'rejects versions that contain non-integers' do
          expect { subject('x.2.3') }.to raise_error(must_begin_with_digits)
          expect { subject('1.y.3') }.to raise_error(must_begin_with_digits)
          expect { subject('1.2.z') }.to raise_error(must_begin_with_digits)
        end

        it 'permits zeroes in version number parts' do
          expect { subject('0.2.3') }.to_not raise_error
          expect { subject('1.0.3') }.to_not raise_error
          expect { subject('1.2.0') }.to_not raise_error
        end

        context 'examples' do
          example '1.9.0' do
            version = subject('1.9.0')
            expect(version.major).to eql 1
            expect(version.minor).to eql 9
            expect(version.patch).to eql 0
          end

          example '1.10.0' do
            version = subject('1.10.0')
            expect(version.major).to eql 1
            expect(version.minor).to eql 10
            expect(version.patch).to eql 0
          end

          example '1.11.0' do
            version = subject('1.11.0')
            expect(version.major).to eql 1
            expect(version.minor).to eql 11
            expect(version.patch).to eql 0
          end
        end
      end

      context 'Section 4' do
        # A pre-release version number MAY be denoted by appending an arbitrary
        # string immediately following the patch version and a dash. The string
        # MUST be comprised of only alphanumerics plus dash [0-9A-Za-z-].
        # Pre-release versions satisfy but have a lower precedence than the
        # associated normal version. Precedence SHOULD be determined by
        # lexicographic ASCII sort order.
        # For instance: 1.0.0-alpha1 < 1.0.0-beta1 < 1.0.0-beta2 < 1.0.0-rc1

        let(:restricted_charset) do
          'Prerelease identifiers MUST use only ASCII alphanumerics and hyphens'
        end

        let(:must_not_be_empty) do
          'Prerelease identifiers MUST NOT be empty'
        end

        let(:no_leading_zeroes) do
          'Prerelease identifiers MUST NOT contain leading zeroes'
        end

        it 'rejects prerelease identifiers with non-alphanumerics' do
          expect { subject('1.2.3-$100') }.to raise_error(restricted_charset)
          expect { subject('1.2.3-rc.1@me') }.to raise_error(restricted_charset)
        end

        it 'rejects empty prerelease versions' do
          expect { subject('1.2.3-') }.to raise_error(must_not_be_empty)
        end

        pending 'permits numeric prerelease identifiers with leading zeroes' do
          expect { subject('1.2.3-01') }.to raise_error(no_leading_zeroes)
        end

        it 'permits numeric prerelease identifiers of zero' do
          expect { subject('1.2.3-0') }.to_not raise_error
        end

        it 'permits non-numeric prerelease identifiers with leading zeroes' do
          expect { subject('1.2.3-0xDEADBEEF') }.to_not raise_error
        end

        context 'examples' do
          example '1.0.0-alpha1' do
            version = subject('1.0.0-alpha1')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'alpha1'
          end

          example '1.0.0-beta1' do
            version = subject('1.0.0-beta1')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'beta1'
          end

          example '1.0.0-beta2' do
            version = subject('1.0.0-beta2')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'beta2'
          end

          example '1.0.0-rc1' do
            version = subject('1.0.0-rc1')
            expect(version.major).to eql 1
            expect(version.minor).to eql 0
            expect(version.patch).to eql 0
            expect(version.prerelease).to eql 'rc1'
          end
        end
      end
    end

  end

  describe '#<=>' do
    def parse(vstring)
      Semantic::Version.parse(vstring)
    end

    context 'Spec v2.0.0' do
      context 'Section 11' do
        # Precedence refers to how versions are compared to each other when
        # ordered. Precedence MUST be calculated by separating the version into
        # major, minor, patch and pre-release identifiers in that order (Build
        # metadata does not figure into precedence). Precedence is determined
        # by the first difference when comparing each of these identifiers from
        # left to right as follows: Major, minor, and patch versions are always
        # compared numerically.
        # Example: 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1.
        # When major, minor, and patch are equal, a pre-release version has
        # lower precedence than a normal version.
        # Example: 1.0.0-alpha < 1.0.0.
        # Precedence for two pre-release versions with the same major, minor,
        # and patch version MUST be determined by comparing each dot separated
        # identifier from left to right until a difference is found as follows:
        # identifiers consisting of only digits are compared numerically and
        # identifiers with letters or hyphens are compared lexically in ASCII
        # sort order. Numeric identifiers always have lower precedence than
        # non-numeric identifiers. A larger set of pre-release fields has a
        # higher precedence than a smaller set, if all of the preceding
        # identifiers are equal.
        # Example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta
        # < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0.

        context 'comparisons without prereleases' do
          subject do
            %w[ 1.0.0 2.0.0 2.1.0 2.1.1 ].map { |v| parse(v) }.shuffle
          end

          example 'sorted order' do
            sorted = subject.sort.map { |v| v.to_s }
            expect(sorted).to eql(%w[ 1.0.0 2.0.0 2.1.0 2.1.1 ])
          end
        end

        context 'comparisons against prereleases' do
          let(:stable) { parse('1.0.0') }
          let(:prerelease) { parse('1.0.0-alpha') }

          example 'prereleases have lower precedence' do
            expect(stable).to be > prerelease
            expect(prerelease).to be < stable
          end
        end

        context 'comparisions between prereleases' do
          example 'identical prereleases are equal' do
            expect(parse('1.0.0-rc1')).to eql parse('1.0.0-rc1')
          end

          example 'non-numeric identifiers sort ASCIIbetically' do
            alpha, beta = parse('1.0.0-alpha'), parse('1.0.0-beta')
            expect(alpha).to be < beta
            expect(beta).to be > alpha
          end

          example 'numeric identifiers sort numerically' do
            two, eleven = parse('1.0.0-2'), parse('1.0.0-11')
            expect(two).to be < eleven
            expect(eleven).to be > two
          end

          example 'non-numeric identifiers have a higher precendence' do
            number, word = parse('1.0.0-1'), parse('1.0.0-one')
            expect(number).to be < word
            expect(word).to be > number
          end

          example 'identifiers are parsed left-to-right' do
            a = parse('1.0.0-these.parts.are.the-same.but.not.waffles.123')
            b = parse('1.0.0-these.parts.are.the-same.but.not.123.waffles')
            expect(b).to be < a
            expect(a).to be > b
          end

          example 'larger identifier sets have precendence' do
            a = parse('1.0.0-alpha')
            b = parse('1.0.0-alpha.1')
            expect(a).to be < b
            expect(b).to be > a
          end

          example 'build metadata does not figure into precendence' do
            a = parse('1.0.0-alpha+SHA1')
            b = parse('1.0.0-alpha+MD5')
            expect(a).to eql b
            expect(a.to_s).to_not eql b.to_s
          end

          example 'sorted order' do
            list = %w[
              1.0.0-alpha
              1.0.0-alpha.1
              1.0.0-alpha.beta
              1.0.0-beta
              1.0.0-beta.2
              1.0.0-beta.11
              1.0.0-rc.1
              1.0.0
            ].map { |v| parse(v) }.shuffle

            sorted = list.sort.map { |v| v.to_s }
            expect(sorted).to eql %w[
              1.0.0-alpha
              1.0.0-alpha.1
              1.0.0-alpha.beta
              1.0.0-beta
              1.0.0-beta.2
              1.0.0-beta.11
              1.0.0-rc.1
              1.0.0
            ]
          end
        end
      end
    end

    context 'Spec v1.0.0' do
      context 'Section 4' do
        # A pre-release version number MAY be denoted by appending an arbitrary
        # string immediately following the patch version and a dash. The string
        # MUST be comprised of only alphanumerics plus dash [0-9A-Za-z-].
        # Pre-release versions satisfy but have a lower precedence than the
        # associated normal version. Precedence SHOULD be determined by
        # lexicographic ASCII sort order.
        # For instance: 1.0.0-alpha1 < 1.0.0-beta1 < 1.0.0-beta2 < 1.0.0-rc1 <
        # 1.0.0

        example 'sorted order' do
          list = %w[
            1.0.0-alpha1
            1.0.0-beta1
            1.0.0-beta2
            1.0.0-rc1
            1.0.0
          ].map { |v| parse(v) }.shuffle

          sorted = list.sort.map { |v| v.to_s }
          expect(sorted).to eql %w[
            1.0.0-alpha1
            1.0.0-beta1
            1.0.0-beta2
            1.0.0-rc1
            1.0.0
          ]
        end
      end
    end

  end

  describe '#next' do
    context 'with :major' do
      it 'returns the next major version' do
        expect(subject('1.0.0').next(:major)).to eql(subject('2.0.0'))
      end

      it 'does not modify the original version' do
        v1 = subject('1.0.0')
        v2 = v1.next(:major)
        expect(v1).to_not eql(v2)
      end

      it 'resets the minor and patch versions to 0' do
        expect(subject('1.1.1').next(:major)).to eql(subject('2.0.0'))
      end

      it 'removes any prerelease or build information' do
        expect(subject('1.0.0-alpha+abc').next(:major)).to eql(subject('2.0.0'))
      end
    end

    context 'with :minor' do
      it 'returns the next minor version' do
        expect(subject('1.0.0').next(:minor)).to eql(subject('1.1.0'))
      end

      it 'does not modify the original version' do
        v1 = subject('1.0.0')
        v2 = v1.next(:minor)
        expect(v1).to_not eql(v2)
      end

      it 'resets the patch version to 0' do
        expect(subject('1.1.1').next(:minor)).to eql(subject('1.2.0'))
      end

      it 'removes any prerelease or build information' do
        expect(subject('1.1.0-alpha+abc').next(:minor)).to eql(subject('1.2.0'))
      end
    end

    context 'with :patch' do
      it 'returns the next patch version' do
        expect(subject('1.1.1').next(:patch)).to eql(subject('1.1.2'))
      end

      it 'does not modify the original version' do
        v1 = subject('1.0.0')
        v2 = v1.next(:patch)
        expect(v1).to_not eql(v2)
      end

      it 'removes any prerelease or build information' do
        expect(subject('1.0.0-alpha+abc').next(:patch)).to eql(subject('1.0.1'))
      end
    end
  end
end