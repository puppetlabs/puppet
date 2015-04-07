#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe "Puppet::Pops::Issues" do
  include Puppet::Pops::Issues

  it "should have an issue called NAME_WITH_HYPHEN" do
    x = Puppet::Pops::Issues::NAME_WITH_HYPHEN
    expect(x.class).to eq(Puppet::Pops::Issues::Issue)
    expect(x.issue_code).to eq(:NAME_WITH_HYPHEN)
  end

  it "should should format a message that requires an argument" do
    x = Puppet::Pops::Issues::NAME_WITH_HYPHEN
    expect(x.format(:name => 'Boo-Hoo',
      :label => Puppet::Pops::Model::ModelLabelProvider.new,
      :semantic => "dummy"
      )).to eq("A String may not have a name containing a hyphen. The name 'Boo-Hoo' is not legal")
  end

  it "should should format a message that does not require an argument" do
    x = Puppet::Pops::Issues::NOT_TOP_LEVEL
    expect(x.format()).to eq("Classes, definitions, and nodes may only appear at toplevel or inside other classes")
  end

end

describe "Puppet::Pops::IssueReporter" do

  let(:acceptor) { Puppet::Pops::Validation::Acceptor.new }

  def fake_positioned(number)
    stub("positioned_#{number}", :line => number, :pos => number)
  end

  def diagnostic(severity,  number)
    Puppet::Pops::Validation::Diagnostic.new(
      severity,
      Puppet::Pops::Issues::Issue.new(number) { "#{severity}#{number}" },
      "#{severity}file",
      fake_positioned(number))
  end

  def warning(number)
    diagnostic(:warning, number)
  end

  def deprecation(number)
    diagnostic(:deprecation, number)
  end

  def error(number)
    diagnostic(:error, number)
  end

  context "given warnings" do

    before(:each) do
      acceptor.accept( warning(1) )
      acceptor.accept( deprecation(1) )
    end

    it "emits warnings if told to emit them" do
      Puppet::Log.expects(:create).twice.with(has_entries(:level => :warning, :message => regexp_matches(/warning1|deprecation1/)))
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_warnings => true })
    end

    it "does not emit warnings if not told to emit them" do
      Puppet::Log.expects(:create).never
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, {})
    end

    it "emits no warnings if :max_warnings is 0" do
      acceptor.accept( warning(2) )
      Puppet[:max_warnings] = 0
      Puppet::Log.expects(:create).once.with(has_entries(:level => :warning, :message => regexp_matches(/deprecation1/)))
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_warnings => true })
    end

    it "emits no more than 1 warning if :max_warnings is 1" do
      acceptor.accept( warning(2) )
      acceptor.accept( warning(3) )
      Puppet[:max_warnings] = 1
      Puppet::Log.expects(:create).twice.with(has_entries(:level => :warning, :message => regexp_matches(/warning1|deprecation1/)))
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_warnings => true })
    end

    it "does not emit more deprecations warnings than the max deprecation warnings" do
      acceptor.accept( deprecation(2) )
      Puppet[:max_deprecations] = 0
      Puppet::Log.expects(:create).once.with(has_entries(:level => :warning, :message => regexp_matches(/warning1/)))
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_warnings => true })
    end

    it "does not emit deprecation warnings, but does emit regular warnings if disable_warnings includes deprecations" do
      Puppet[:disable_warnings] = 'deprecations'
      Puppet::Log.expects(:create).once.with(has_entries(:level => :warning, :message => regexp_matches(/warning1/)))
      Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_warnings => true })
    end
  end

  context "given errors" do
    it "logs nothing, but raises the given :message if :emit_errors is repressing error logging" do
      acceptor.accept( error(1) )
      Puppet::Log.expects(:create).never
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_errors => false, :message => 'special'})
      end.to raise_error(Puppet::ParseError, 'special')
    end

    it "prefixes :message if a single error is raised" do
      acceptor.accept( error(1) )
      Puppet::Log.expects(:create).never
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :message => 'special'})
      end.to raise_error(Puppet::ParseError, /special error1/)
    end

    it "logs nothing and raises immediately if there is only one error" do
      acceptor.accept( error(1) )
      Puppet::Log.expects(:create).never
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { })
      end.to raise_error(Puppet::ParseError, /error1/)
    end

    it "logs nothing and raises immediately if there are multiple errors but max_errors is 0" do
      acceptor.accept( error(1) )
      acceptor.accept( error(2) )
      Puppet[:max_errors] = 0
      Puppet::Log.expects(:create).never
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { })
      end.to raise_error(Puppet::ParseError, /error1/)
    end

    it "logs the :message if there is more than one allowed error" do
      acceptor.accept( error(1) )
      acceptor.accept( error(2) )
      Puppet::Log.expects(:create).times(3).with(has_entries(:level => :err, :message => regexp_matches(/error1|error2|special/)))
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :message => 'special'})
      end.to raise_error(Puppet::ParseError, /Giving up/)
    end

    it "emits accumulated errors before raising a 'giving up' message if there are more errors than allowed" do
      acceptor.accept( error(1) )
      acceptor.accept( error(2) )
      acceptor.accept( error(3) )
      Puppet[:max_errors] = 2
      Puppet::Log.expects(:create).times(2).with(has_entries(:level => :err, :message => regexp_matches(/error1|error2/)))
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { })
      end.to raise_error(Puppet::ParseError, /3 errors.*Giving up/)
    end

    it "emits accumulated errors before raising a 'giving up' message if there are multiple errors but fewer than limits" do
      acceptor.accept( error(1) )
      acceptor.accept( error(2) )
      acceptor.accept( error(3) )
      Puppet[:max_errors] = 4
      Puppet::Log.expects(:create).times(3).with(has_entries(:level => :err, :message => regexp_matches(/error[123]/)))
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { })
      end.to raise_error(Puppet::ParseError, /3 errors.*Giving up/)
    end

    it "emits errors regardless of disable_warnings setting" do
      acceptor.accept( error(1) )
      acceptor.accept( error(2) )
      Puppet[:disable_warnings] = 'deprecations'
      Puppet::Log.expects(:create).times(2).with(has_entries(:level => :err, :message => regexp_matches(/error1|error2/)))
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { })
      end.to raise_error(Puppet::ParseError, /Giving up/)
    end
  end

  context "given both" do

    it "logs warnings and errors" do
      acceptor.accept( warning(1) )
      acceptor.accept( error(1) )
      acceptor.accept( error(2) )
      acceptor.accept( error(3) )
      acceptor.accept( deprecation(1) )
      Puppet[:max_errors] = 2
      Puppet::Log.expects(:create).twice.with(has_entries(:level => :warning, :message => regexp_matches(/warning1|deprecation1/)))
      Puppet::Log.expects(:create).twice.with(has_entries(:level => :err, :message => regexp_matches(/error[123]/)))
      expect do
        Puppet::Pops::IssueReporter.assert_and_report(acceptor, { :emit_warnings => true })
      end.to raise_error(Puppet::ParseError, /3 errors.*2 warnings.*Giving up/)
    end
  end
end
