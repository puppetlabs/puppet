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

RSpec::Matchers.define :have_matching_log do |expected|
  match do |actual|
    actual.map(&:to_s).any? { |item| item =~ expected }
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

  supports_block_expectations

  failure_message do |block|
    "expected exit with code #{expected} but " +
      (actual.nil? ? " exit was not called" : "we exited with #{actual} instead")
  end

  failure_message_when_negated do |block|
    "expected that exit would not be called with #{expected}"
  end

  description do
    "expect exit with #{expected}"
  end
end


RSpec::Matchers.define :have_printed do |expected|

  case expected
  when String, Regexp, Proc
    expected = expected
  else
    expected = expected.to_s
  end

  chain :and_exit_with do |code|
    @expected_exit_code = code
  end

  define_method :matches_exit_code? do |actual|
    @expected_exit_code.nil? || @expected_exit_code == actual
  end

  define_method :matches_output? do |actual|
    return false unless actual
    case expected
      when String
        actual.include?(expected)
      when Regexp
        expected.match(actual)
      when Proc
        expected.call(actual)
      else
        raise ArgumentError, "No idea how to match a #{actual.class.name}"
    end
  end

  match do |block|
    $stderr = $stdout = StringIO.new
    $stdout.set_encoding('UTF-8') if $stdout.respond_to?(:set_encoding)

    begin
      block.call
    rescue SystemExit => e
      raise unless @expected_exit_code
      @actual_exit_code = e.status
    ensure
      $stdout.rewind
      @actual = $stdout.read

      $stdout = STDOUT
      $stderr = STDERR
    end

    matches_output?(@actual) && matches_exit_code?(@actual_exit_code)
  end

  supports_block_expectations

  failure_message do |actual|
    if actual.nil? then
      "expected #{expected.inspect}, but nothing was printed"
    else
      if !@expected_exit_code.nil? && matches_output?(actual)
        "expected exit with code #{@expected_exit_code} but " +
          (@actual_exit_code.nil? ? " exit was not called" : "exited with #{@actual_exit_code} instead")
      else
        "expected #{expected.inspect} to be printed; got:\n#{actual}"
      end
    end
  end

  failure_message_when_negated do |actual|
    if @expected_exit_code && matches_exit_code?(@actual_exit_code)
      "expected exit code to not be #{@actual_exit_code}"
    else
      "expected #{expected.inspect} to not be printed; got:\n#{actual}"
    end
  end

  description do
    "expect #{expected.inspect} to be printed" + (@expected_exit_code.nil ? '' : " with exit code #{@expected_exit_code}")
  end
end

RSpec::Matchers.define :equal_attributes_of do |expected|
  match do |actual|
    actual.instance_variables.all? do |attr|
      actual.instance_variable_get(attr) == expected.instance_variable_get(attr)
    end
  end
end

RSpec::Matchers.define :equal_resource_attributes_of do |expected|
  match do |actual|
    actual.keys do |attr|
      actual[attr] == expected[attr]
    end
  end
end

RSpec::Matchers.define :be_one_of do |*expected|
  match do |actual|
    expected.include? actual
  end

  failure_message do |actual|
    "expected #{actual.inspect} to be one of #{expected.map(&:inspect).join(' or ')}"
  end
end
