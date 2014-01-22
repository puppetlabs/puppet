#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/package/ports/pkg_record'

describe Puppet::Util::Package::Ports::PkgRecord do

#  it { described_class.should be_a Puppet::Util::Package::Ports::Functions }
  it { described_class.should < Puppet::Util::Package::Ports::Record }

  describe "::std_fields" do
    it do
      described_class.std_fields.sort.should == [
        :pkgname,
        :portinfo,
        :portorigin,
        :portstatus
      ]
    end
  end

  describe "::default_fields" do
    it do
      described_class.default_fields.sort.should == [
        :options,
        :options_file,
        :options_files,
        :pkgname,
        :pkgversion,
        :portinfo,
        :portname,
        :portorigin,
        :portstatus
      ]
    end
  end

  describe "::deps_for_amend" do
    [
      [:options, [:portname, :portorigin]],
      [:options_file, [:portname, :portorigin]],
      [:options_files, [:portname, :portorigin]],
      [:pkgversion, [:pkgname]],
    ].each do |field, deps|
      it { described_class.deps_for_amend[field].should == deps}
    end
  end

  describe "#amend!(fields)" do
    hash = Hash[{:pkgname=>'bar-0.1.2', :portorigin=>'foo/bar22'}]
    context "on #{described_class}[#{hash.inspect}]" do
      subject { described_class[hash] }
      [
        # 1
        [
          [:portname, :pkgversion],
          {:portname => 'bar', :pkgversion => '0.1.2'}
        ],
        # 2
        [
          [],
          { }
        ],
      ].each do |fields, result|
        context "#amend!(#{fields.inspect})" do
          let(:fields) { fields }
          let(:result) { result }
          it "changes self to #{result.inspect}" do
            s = subject
            s.amend!(fields)
            s.should == result
          end
        end
      end
    end
  end
end

