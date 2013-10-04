require 'stringio'

########################################################################
# Backward compatibility for Jenkins outdated environment.
module RSpec
  module Matchers
    module BlockAliases
      alias_method :to,     :should      unless method_defined? :to
      alias_method :to_not, :should_not  unless method_defined? :to_not
      alias_method :not_to, :should_not  unless method_defined? :not_to
    end
  end
end


########################################################################
# Custom matchers...
RSpec::Matchers.define :have_matching_element do |expected|
  match do |actual|
    actual.any? { |item| item =~ expected }
  end
end


RSpec::Matchers.define :exit_with do |expected|
  actual = nil
  match do |block|
    begin
      block.call
    rescue SystemExit => e
      actual = e.status
    end
    actual and actual == expected
  end
  failure_message_for_should do |block|
    "expected exit with code #{expected} but " +
      (actual.nil? ? " exit was not called" : "we exited with #{actual} instead")
  end
  failure_message_for_should_not do |block|
    "expected that exit would not be called with #{expected}"
  end
  description do
    "expect exit with #{expected}"
  end
end

class HavePrintedMatcher
  attr_accessor :expected, :actual

  def initialize(expected)
    case expected
    when String, Regexp
      @expected = expected
    else
      @expected = expected.to_s
    end
  end

  def matches?(block)
    begin
      $stderr = $stdout = StringIO.new
      block.call
      $stdout.rewind
      @actual = $stdout.read
    ensure
      $stdout = STDOUT
      $stderr = STDERR
    end

    if @actual then
      case @expected
      when String
        @actual.include? @expected
      when Regexp
        @expected.match @actual
      end
    else
      false
    end
  end

  def failure_message_for_should
    if @actual.nil? then
      "expected #{@expected.inspect}, but nothing was printed"
    else
      "expected #{@expected.inspect} to be printed; got:\n#{@actual}"
    end
  end

  def description
    "expect #{@expected.inspect} to be printed"
  end
end

def have_printed(what)
  HavePrintedMatcher.new(what)
end

RSpec::Matchers.define :equal_attributes_of do |expected|
  match do |actual|
    actual.instance_variables.all? do |attr|
      actual.instance_variable_get(attr) == expected.instance_variable_get(attr)
    end
  end
end

RSpec::Matchers.define :be_one_of do |*expected|
  match do |actual|
    expected.include? actual
  end

  failure_message_for_should do |actual|
    "expected #{actual.inspect} to be one of #{expected.map(&:inspect).join(' or ')}"
  end
end
