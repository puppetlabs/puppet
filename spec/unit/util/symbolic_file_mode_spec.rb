#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/symbolic_file_mode'

describe Puppet::Util::SymbolicFileMode do
  include Puppet::Util::SymbolicFileMode

  describe "#valid_symbolic_mode?" do
    %w{
         0  0000  1  1  7  11  77  111  777  11
         0 00000 01 01 07 011 077 0111 0777 011
         = - + u= g= o= a= u+ g+ o+ a+ u- g- o- a- ugo= ugoa= ugugug=
         a=,u=,g= a=,g+
         =rwx +rwx -rwx
         644 go-w =rw,+X +X 755 u=rwx,go=rx u=rwx,go=u-w go= g=u-w
         755 0755
    }.each do |input|
      it "should treat #{input.inspect} as valid" do
        expect(valid_symbolic_mode?(input)).to be_truthy
      end
    end

    [0000, 0111, 0640, 0755, 0777].each do |input|
      it "should treat the int #{input.to_s(8)} as value" do
        expect(valid_symbolic_mode?(input)).to be_truthy
      end
    end

    %w{
          -1  -8  8  9  18  19  91  81  000000  11111  77777
         0-1 0-8 08 09 018 019 091 081 0000000 011111 077777
         u g o a ug uo ua ag
    }.each do |input|
      it "should treat #{input.inspect} as invalid" do
        expect(valid_symbolic_mode?(input)).to be_falsey
      end
    end
  end

  describe "#normalize_symbolic_mode" do
    it "should turn an int into a string" do
      expect(normalize_symbolic_mode(12)).to be_an_instance_of String
    end

    it "should not add a leading zero to an int" do
      expect(normalize_symbolic_mode(12)).not_to match(/^0/)
    end

    it "should not add a leading zero to a string with a number" do
      expect(normalize_symbolic_mode("12")).not_to match(/^0/)
    end

    it "should string a leading zero from a number" do
      expect(normalize_symbolic_mode("012")).to eq('12')
    end

    it "should pass through any other string" do
      expect(normalize_symbolic_mode("u=rwx")).to eq('u=rwx')
    end
  end

  describe "#symbolic_mode_to_int" do
    {
      "0654"            => 00654,
      "u+r"             => 00400,
      "g+r"             => 00040,
      "a+r"             => 00444,
      "a+x"             => 00111,
      "o+t"             => 01000,
      ["o-t", 07777]    => 06777,
      ["a-x", 07777]    => 07666,
      ["a-rwx", 07777]  => 07000,
      ["ug-rwx", 07777] => 07007,
      "a+x,ug-rwx"      => 00001,
      # My experimentation on debian suggests that +g ignores the sgid flag
      ["a+g", 02060]    => 02666,
      # My experimentation on debian suggests that -g ignores the sgid flag
      ["a-g", 02666]    => 02000,
      "g+x,a+g"         => 00111,
      # +X without exec set in the original should not set anything
      "u+x,g+X"         => 00100,
      "g+X"             => 00000,
      # +X only refers to the original, *unmodified* file mode!
      ["u+x,a+X", 0600] => 00700,
      # Examples from the MacOS chmod(1) manpage
      "0644"            => 00644,
      ["go-w", 07777]   => 07755,
      ["=rw,+X", 07777] => 07777,
      ["=rw,+X", 07766] => 07777,
      ["=rw,+X", 07676] => 07777,
      ["=rw,+X", 07667] => 07777,
      ["=rw,+X", 07666] => 07666,
      "0755"            => 00755,
      "u=rwx,go=rx"     => 00755,
      "u=rwx,go=u-w"    => 00755,
      ["go=", 07777]    => 07700,
      ["g=u-w", 07777]  => 07757,
      ["g=u-w", 00700]  => 00750,
      ["g=u-w", 00600]  => 00640,
      ["g=u-w", 00500]  => 00550,
      ["g=u-w", 00400]  => 00440,
      ["g=u-w", 00300]  => 00310,
      ["g=u-w", 00200]  => 00200,
      ["g=u-w", 00100]  => 00110,
      ["g=u-w", 00000]  => 00000,
      # Cruel, but legal, use of the action set.
      ["g=u+r-w", 0300] => 00350,
      # Empty assignments.
      ["u=",  00000]    => 00000,
      ["u=",  00600]    => 00000,
      ["ug=", 00000]    => 00000,
      ["ug=", 00600]    => 00000,
      ["ug=", 00660]    => 00000,
      ["ug=", 00666]    => 00006,
      ["=",   00000]    => 00000,
      ["=",   00666]    => 00000,
      ["+",   00000]    => 00000,
      ["+",   00124]    => 00124,
      ["-",   00000]    => 00000,
      ["-",   00124]    => 00124,
    }.each do |input, result|
      from = input.is_a?(Array) ? "#{input[0]}, 0#{input[1].to_s(8)}" : input
      it "should map #{from.inspect} to #{result.inspect}" do
        expect(symbolic_mode_to_int(*input)).to eq(result)
      end
    end

    # Now, test some failure modes.
    it "should fail if no mode is given" do
      expect { symbolic_mode_to_int('') }.
        to raise_error Puppet::Error, /empty mode string/
    end

    %w{u g o ug uo go ugo a uu u/x u!x u=r,,g=r}.each do |input|
      it "should fail if no (valid) action is given: #{input.inspect}" do
        expect { symbolic_mode_to_int(input) }.
          to raise_error Puppet::Error, /Missing action/
      end
    end

    %w{u+q u-rwF u+rw,g+rw,o+RW}.each do |input|
      it "should fail with unknown op #{input.inspect}" do
        expect { symbolic_mode_to_int(input) }.
          to raise_error Puppet::Error, /Unknown operation/
      end
    end

    it "should refuse to subtract the conditional execute op" do
      expect { symbolic_mode_to_int("o-rwX") }.
        to raise_error Puppet::Error, /only works with/
    end

    it "should refuse to set to the conditional execute op" do
      expect { symbolic_mode_to_int("o=rwX") }.
        to raise_error Puppet::Error, /only works with/
    end

    %w{8 08 9 09 118 119}.each do |input|
      it "should fail for decimal modes: #{input.inspect}" do
        expect { symbolic_mode_to_int(input) }.
          to raise_error Puppet::Error, /octal/
      end
    end

    it "should set the execute bit on a directory, without exec in original" do
      expect(symbolic_mode_to_int("u+X", 0444, true).to_s(8)).to eq("544")
      expect(symbolic_mode_to_int("g+X", 0444, true).to_s(8)).to eq("454")
      expect(symbolic_mode_to_int("o+X", 0444, true).to_s(8)).to eq("445")
      expect(symbolic_mode_to_int("+X",  0444, true).to_s(8)).to eq("555")
    end

    it "should set the execute bit on a file with exec in the original" do
      expect(symbolic_mode_to_int("+X", 0544).to_s(8)).to eq("555")
    end

    it "should not set the execute bit on a file without exec on the original even if set by earlier DSL" do
      expect(symbolic_mode_to_int("u+x,go+X", 0444).to_s(8)).to eq("544")
    end
  end
end
