require 'stringio'

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

RSpec::Matchers.define :have_matching_log_with_source do |expected, file, line, pos|
  match do |actual|
    actual.any? { |item| item.message =~ expected && item.file == file && item.line == line && item.pos == pos }
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
