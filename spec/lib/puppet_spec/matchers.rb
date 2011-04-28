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


RSpec::Matchers.define :have_printed do |expected|
  match do |block|
    $stderr = $stdout = StringIO.new

    begin
      block.call
    ensure
      $stdout.rewind
      @actual = $stdout.read

      $stdout = STDOUT
      $stderr = STDERR
    end

    if @actual then
      case expected
      when String
        @actual.include? expected
      when Regexp
        expected.match @actual
      else
        raise ArgumentError, "No idea how to match a #{@actual.class.name}"
      end
    end
  end

  failure_message_for_should do |actual|
    if actual.nil? then
      "expected #{expected.inspect}, but nothing was printed"
    else
      "expected #{expected.inspect} to be printed; got:\n#{actual}"
    end
  end

  description do
    "expect #{expected.inspect} to be printed"
  end

  diffable
end
