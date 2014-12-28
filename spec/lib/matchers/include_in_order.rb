RSpec::Matchers.define :include_in_order do |*expected|
  include RSpec::Matchers::Pretty

  match do |actual|
    elements = expected.dup
    actual.each do |elt|
      if elt == elements.first
        elements.shift
      end
    end
    elements.empty?
  end

  def failure_message
    "expected #{@actual.inspect} to include#{expected_to_sentence} in order"
  end

  def failure_message_when_negated
    "expected #{@actual.inspect} not to include#{expected_to_sentence} in order"
  end
end
