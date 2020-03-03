require 'spec_helper'
require 'puppet/util/package/version/pip'

describe Puppet::Util::Package::Version::Pip do
  describe "initialization" do
    shared_examples_for 'a valid version' do |input_version, output = input_version|
      [input_version, input_version.swapcase].each do |input|
        it "transforms #{input} back to string(#{output}) succesfully" do
          version = described_class.parse(input)
          expect(version.to_s).to eq(output)
        end
      end

      describe "comparison" do
        version = described_class.parse(input_version)

        # rubocop:disable UselessComparison
        it "#{input_version} shouldn't be lesser than itself" do
          expect(version <  version).to eq(false)
        end

        it "#{input_version} shouldn't be greater than itself" do
          expect(version >  version).to eq(false)
        end

        it "#{input_version} shouldn't be equal with itself" do
          expect(version != version).to eq(false)
        end

        it "#{input_version} should be equal to itself" do
          expect(version == version).to eq(true)
        end
      end
    end

    shared_examples_for 'an invalid version' do |invalid_input|
      [invalid_input, invalid_input.swapcase].each do |input|
        it "should not be able to transform #{invalid_input} to string" do
          expect{ described_class.parse(input) }.to raise_error(described_class::ValidationFailure)
        end
      end

      describe "comparison" do
        valid_version = described_class.parse("1.0")

        it "should raise error when checking if #{invalid_input} is lesser than a valid version" do
          expect{ valid_version <  invalid_input }.to raise_error(described_class::ValidationFailure)
        end

        it "should raise error when checking if #{invalid_input} is greater than a valid version" do
          expect{ valid_version >  invalid_input }.to raise_error(described_class::ValidationFailure)
        end

        it "should raise error when checking if #{invalid_input} is greater or equal than a valid version" do
          expect{ valid_version >= invalid_input }.to raise_error(described_class::ValidationFailure)
        end

        it "should raise error when checking if #{invalid_input} is lesser or equal than a valid version" do
          expect{ valid_version <= invalid_input }.to raise_error(described_class::ValidationFailure)
        end
      end
    end

    describe "when only release segment is present in provided version" do
      context "should work with any number of integer elements" do
        context "when it has 1 element" do
          it_should_behave_like 'a valid version', "1"
        end
        context "when it has 2 elements" do
          it_should_behave_like 'a valid version', "1.1"
        end

        context "when it has 3 elements" do
          it_should_behave_like 'a valid version', "1.1.1"
        end

        context "when it has 4 elements" do
          it_should_behave_like 'a valid version', "1.1.1.1"
        end

        context "when it has 10 elements" do
          it_should_behave_like 'a valid version', "1.1.1.1.1.1.1.1.1.1"
        end
      end

      describe "should work with elements which are zero" do
        context "when it ends with 1 zero" do
          it_should_behave_like 'a valid version', "1.0"
        end

        context "when it ends with 2 zeros" do
          it_should_behave_like 'a valid version', "1.0.0"
        end

        context "when it ends with 3 zeros" do
          it_should_behave_like 'a valid version', "1.0.0.0"
        end

        context "when it starts with 1 zero" do
          it_should_behave_like 'a valid version', "0.1"
        end

        context "when it starts with 2 zeros" do
          it_should_behave_like 'a valid version', "0.0.1"
        end

        context "when it starts with 3 zeros" do
          it_should_behave_like 'a valid version', "0.0.0.1"
        end

        context "when it is just a zero" do
          it_should_behave_like 'a valid version', "0"
        end

        context "when it is full of just zeros" do
          it_should_behave_like 'a valid version', "0.0.0"
        end
      end

      describe "should work with elements containing multiple digits" do
        context "when it has two digit elements" do
          it_should_behave_like 'a valid version', "1.10.1"
        end

        context "when it has three digit elements" do
          it_should_behave_like 'a valid version', "1.101.1.11"
        end

        context "when it has four digit elements" do
          it_should_behave_like 'a valid version', "2019.0.11"
        end

        context "when it has a numerical element starting with zero" do
          # the zero will dissapear
          it_should_behave_like 'a valid version', "1.09.10", "1.9.10"
        end

        context "when it starts with multiple zeros" do
          # the zeros will dissapear
          it_should_behave_like 'a valid version', "0010.0000.0011", "10.0.11"
        end
      end

      context "should fail because of misplaced letters" do
        context "when it starts with letters" do
          it_should_behave_like 'an invalid version', "d.2"
          it_should_behave_like 'an invalid version', "ee.2"
        end

        context "when it has only letters" do
          it_should_behave_like 'an invalid version', "d.c"
          it_should_behave_like 'an invalid version', "dd.c"
        end
      end
    end

    describe "when the epoch segment is present in provided version" do
      context "should work when epoch is an integer" do
        context "when epoch has 1 digit" do
          it_should_behave_like 'a valid version', "1!1.0.0"
        end

        context "when epoch has 2 digits" do
          it_should_behave_like 'a valid version', "10!1.0.0"
        end

        context "when epoch is zero" do
          # versions without epoch specified are considered to have epoch 0
          # it is accepted as input but it should be ignored at output
          it_should_behave_like 'a valid version', "0!1.0.0", "1.0.0"
        end
      end

      context "should fail when epoch contains letters" do
        context "when epoch starts with a letter" do
          it_should_behave_like 'an invalid version', "a9!1.0.0"
        end

        context "when epoch ends with a letter" do
          it_should_behave_like 'an invalid version', "9a!1.0.0"
        end
      end
    end

    describe "when the pre-release segment is present in provided version" do
      context "when pre-release contains the letter a" do
        it_should_behave_like 'a valid version', "1.0a", "1.0a0"
        it_should_behave_like 'a valid version', "1.0a0"
      end

      context "when pre-release contains the letter b" do
        it_should_behave_like 'a valid version', "1.0b", "1.0b0"
        it_should_behave_like 'a valid version', "1.0b0"
      end

      context "when pre-release contains the letter c" do
        it_should_behave_like 'a valid version', "1.0c",  "1.0rc0"
        it_should_behave_like 'a valid version', "1.0c0", "1.0rc0"
      end

      context "when pre-release contains the string alpha" do
        it_should_behave_like 'a valid version', "1.0alpha",  "1.0a0"
        it_should_behave_like 'a valid version', "1.0alpha0", "1.0a0"
      end

      context "when pre-release contains the string beta" do
        it_should_behave_like 'a valid version', "1.0beta",  "1.0b0"
        it_should_behave_like 'a valid version', "1.0beta0", "1.0b0"
      end

      context "when pre-release contains the string rc" do
        it_should_behave_like 'a valid version', "1.0rc",  "1.0rc0"
        it_should_behave_like 'a valid version', "1.0rc0", "1.0rc0"
      end

      context "when pre-release contains the string pre" do
        it_should_behave_like 'a valid version', "1.0pre",  "1.0rc0"
        it_should_behave_like 'a valid version', "1.0pre0", "1.0rc0"
      end

      context "when pre-release contains the string preview" do
        it_should_behave_like 'a valid version', "1.0preview",  "1.0rc0"
        it_should_behave_like 'a valid version', "1.0preview0", "1.0rc0"
      end

      context "when pre-release contains multiple zeros at the beginning" do
        it_should_behave_like 'a valid version', "1.0.beta.00",  "1.0b0"
        it_should_behave_like 'a valid version', "1.0.beta.002", "1.0b2"
      end

      context "when pre-release elements are separated by dots" do
        it_should_behave_like 'a valid version', "1.0.alpha",   "1.0a0"
        it_should_behave_like 'a valid version', "1.0.alpha.0", "1.0a0"
        it_should_behave_like 'a valid version', "1.0.alpha.2", "1.0a2"
      end

      context "when pre-release elements are separated by dashes" do
        it_should_behave_like 'a valid version', "1.0-alpha",   "1.0a0"
        it_should_behave_like 'a valid version', "1.0-alpha-0", "1.0a0"
        it_should_behave_like 'a valid version', "1.0-alpha-2", "1.0a2"
      end

      context "when pre-release elements are separated by underscores" do
        it_should_behave_like 'a valid version', "1.0_alpha",   "1.0a0"
        it_should_behave_like 'a valid version', "1.0_alpha_0", "1.0a0"
        it_should_behave_like 'a valid version', "1.0_alpha_2", "1.0a2"
      end

      context "when pre-release elements are separated by mixed symbols" do
        it_should_behave_like 'a valid version', "1.0-alpha_5", "1.0a5"
        it_should_behave_like 'a valid version', "1.0-alpha.5", "1.0a5"
        it_should_behave_like 'a valid version', "1.0_alpha-5", "1.0a5"
        it_should_behave_like 'a valid version', "1.0_alpha.5", "1.0a5"
        it_should_behave_like 'a valid version', "1.0.alpha-5", "1.0a5"
        it_should_behave_like 'a valid version', "1.0.alpha_5", "1.0a5"
      end
    end

    describe "when the post-release segment is present in provided version" do
      context "when post-release is just an integer" do
        it_should_behave_like 'a valid version', "1.0-9",  "1.0.post9"
        it_should_behave_like 'a valid version', "1.0-10", "1.0.post10"
      end

      context "when post-release is just an integer and starts with zero" do
        it_should_behave_like 'a valid version', "1.0-09",  "1.0.post9"
        it_should_behave_like 'a valid version', "1.0-009", "1.0.post9"
      end

      context "when post-release contains the string post" do
        it_should_behave_like 'a valid version', "1.0post",  "1.0.post0"
        it_should_behave_like 'a valid version', "1.0post0", "1.0.post0"
        it_should_behave_like 'a valid version', "1.0post1", "1.0.post1"
        it_should_behave_like 'an invalid version', "1.0-0.post1"
      end

      context "when post-release contains the string rev" do
        it_should_behave_like 'a valid version', "1.0rev",  "1.0.post0"
        it_should_behave_like 'a valid version', "1.0rev0", "1.0.post0"
        it_should_behave_like 'a valid version', "1.0rev1", "1.0.post1"
        it_should_behave_like 'an invalid version', "1.0-0.rev1"
      end

      context "when post-release contains the letter r" do
        it_should_behave_like 'a valid version', "1.0r",  "1.0.post0"
        it_should_behave_like 'a valid version', "1.0r0", "1.0.post0"
        it_should_behave_like 'a valid version', "1.0r1", "1.0.post1"
        it_should_behave_like 'an invalid version', "1.0-0.r1"
      end

      context "when post-release elements are separated by dashes" do
        it_should_behave_like 'a valid version', "1.0-post-22", "1.0.post22"
        it_should_behave_like 'a valid version', "1.0-rev-22",  "1.0.post22"
        it_should_behave_like 'a valid version', "1.0-r-22",    "1.0.post22"
      end

      context "when post-release elements are separated by underscores" do
        it_should_behave_like 'a valid version', "1.0_post_22", "1.0.post22"
        it_should_behave_like 'a valid version', "1.0_rev_22",  "1.0.post22"
        it_should_behave_like 'a valid version', "1.0_r_22",    "1.0.post22"
      end

      context "when post-release elements are separated by dots" do
        it_should_behave_like 'a valid version', "1.0.post.22", "1.0.post22"
        it_should_behave_like 'a valid version', "1.0.rev.22",  "1.0.post22"
        it_should_behave_like 'a valid version', "1.0.r.22",    "1.0.post22"
      end

      context "when post-release elements are separated by mixed symbols" do
        it_should_behave_like 'a valid version', "1.0-r_5", "1.0.post5"
        it_should_behave_like 'a valid version', "1.0-r.5", "1.0.post5"
        it_should_behave_like 'a valid version', "1.0_r-5", "1.0.post5"
        it_should_behave_like 'a valid version', "1.0_r.5", "1.0.post5"
        it_should_behave_like 'a valid version', "1.0.r-5", "1.0.post5"
        it_should_behave_like 'a valid version', "1.0.r_5", "1.0.post5"
      end
    end

    describe "when the dev release segment is present in provided version" do
      context "when dev release is only the keyword dev" do
        it_should_behave_like 'a valid version', "1.0dev",  "1.0.dev0"
        it_should_behave_like 'a valid version', "1.0-dev", "1.0.dev0"
        it_should_behave_like 'a valid version', "1.0_dev", "1.0.dev0"
        it_should_behave_like 'a valid version', "1.0.dev", "1.0.dev0"
      end

      context "when dev release contains the keyword dev and a number" do
        it_should_behave_like 'a valid version', "1.0dev2",    "1.0.dev2"
        it_should_behave_like 'a valid version', "1.0-dev33",  "1.0.dev33"
        it_should_behave_like 'a valid version', "1.0.dev11",  "1.0.dev11"
        it_should_behave_like 'a valid version', "1.0_dev101", "1.0.dev101"
      end

      context "when dev release's number element starts with 0" do
        it_should_behave_like 'a valid version', "1.0dev02",     "1.0.dev2"
        it_should_behave_like 'a valid version', "1.0-dev033",   "1.0.dev33"
        it_should_behave_like 'a valid version', "1.0_dev0101",  "1.0.dev101"
        it_should_behave_like 'a valid version', "1.0.dev00011", "1.0.dev11"
      end

      context "when dev release elements are separated by dashes" do
        it_should_behave_like 'a valid version', "1.0-dev",    "1.0.dev0"
        it_should_behave_like 'a valid version', "1.0-dev-2",  "1.0.dev2"
        it_should_behave_like 'a valid version', "1.0-dev-22", "1.0.dev22"
      end

      context "when dev release elements are separated by underscores" do
        it_should_behave_like 'a valid version', "1.0_dev",    "1.0.dev0"
        it_should_behave_like 'a valid version', "1.0_dev_2",  "1.0.dev2"
        it_should_behave_like 'a valid version', "1.0_dev_22", "1.0.dev22"
      end

      context "when dev release elements are separated by dots" do
        it_should_behave_like 'a valid version', "1.0.dev",    "1.0.dev0"
        it_should_behave_like 'a valid version', "1.0.dev.2",  "1.0.dev2"
        it_should_behave_like 'a valid version', "1.0.dev.22", "1.0.dev22"
      end

      context "when dev release elements are separated by mixed symbols" do
        it_should_behave_like 'a valid version', "1.0-dev_5", "1.0.dev5"
        it_should_behave_like 'a valid version', "1.0-dev.5", "1.0.dev5"
        it_should_behave_like 'a valid version', "1.0_dev-5", "1.0.dev5"
        it_should_behave_like 'a valid version', "1.0_dev.5", "1.0.dev5"
        it_should_behave_like 'a valid version', "1.0.dev-5", "1.0.dev5"
        it_should_behave_like 'a valid version', "1.0.dev_5", "1.0.dev5"
      end
    end

    describe "when the local version segment is present in provided version" do
      it_should_behave_like 'an invalid version', "1.0+"

      context "when local version is just letters" do
        it_should_behave_like 'a valid version', "1.0+local"
        it_should_behave_like 'a valid version', "1.0+Local", "1.0+local"
      end

      context "when local version contains numbers" do
        it_should_behave_like 'a valid version', "1.0+10"
        it_should_behave_like 'a valid version', "1.0+01",    "1.0+1"
        it_should_behave_like 'a valid version', "1.0+01L",   "1.0+01l"
        it_should_behave_like 'a valid version', "1.0+L101L", "1.0+l101l"
      end

      context "when local version contains multiple elements" do
        it_should_behave_like 'a valid version', "1.0+10.local"
        it_should_behave_like 'a valid version', "1.0+abc.def.ghi"
        it_should_behave_like 'a valid version', "1.0+01.abc",            "1.0+1.abc"
        it_should_behave_like 'a valid version', "1.0+01L.0001",          "1.0+01l.1"
        it_should_behave_like 'a valid version', "1.0+L101L.local",       "1.0+l101l.local"
        it_should_behave_like 'a valid version', "1.0+dash-undrsc_dot.5", "1.0+dash.undrsc.dot.5"
      end
    end
  end

  describe "comparison of versions" do
    # This array must remain sorted (smallest to highest version).
    versions = [
      "0.1",
      "0.10",
      "0.10.1",
      "0.10.1.0.1",
      "1.0.dev456",
      "1.0a1",
      "1.0a2.dev456",
      "1.0a12.dev456",
      "1.0a12",
      "1.0b1.dev456",
      "1.0b2",
      "1.0b2.post345.dev456",
      "1.0b2.post345",
      "1.0b2-346",
      "1.0c1.dev456",
      "1.0c1",
      "1.0rc2",
      "1.0c3",
      "1.0",
      "1.0.post456.dev34",
      "1.0.post456",
      "1.1.dev1",
      "1.2+123abc",
      "1.2+123abc456",
      "1.2+abc",
      "1.2+abc123",
      "1.2+abc123def",
      "1.2+1234.abc",
      "1.2+123456",
      "1.2.r32+123456",
      "1.2.rev33+123456",
      "1!1.0b2.post345.dev456",
      "1!1.0",
      "1!1.0.post456.dev34",
      "1!1.0.post456",
      "1!1.2.rev33+123456",
      "2!2.3.4.alpha5.rev6.dev7+abc89"
    ]

    versions.combination(2).to_a.each do |version_pair|
      lower_version = described_class.parse(version_pair.first)
      greater_version = described_class.parse(version_pair.last)
      
      it "#{lower_version} should be equal to #{lower_version}" do
        expect(lower_version == lower_version).to eq(true)
      end

      it "#{lower_version} should not be equal to #{greater_version}" do
        expect(lower_version != greater_version).to eq(true)
      end

      it "#{lower_version} should be lower than #{greater_version}" do
        expect(lower_version < greater_version).to eq(true)
      end

      it "#{greater_version} should be greater than #{lower_version}" do
        expect(greater_version > lower_version).to eq(true)
      end
    end
  end
end
