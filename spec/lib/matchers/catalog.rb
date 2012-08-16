RSpec::Matchers.define :be_equivalent_to do |expected|
  match do |actual|
    compare_catalogs(actual, expected)
  end

  failure_message_for_should do |actual|
    "expected #{actual} would be equivalent to #{expected}"
  end

  failure_message_for_should_not do |actual|
    "expected #{actual} would not be equivalent to #{expected}"
  end

  description do
    "be equivalent to #{expected}"
  end

  def compare_catalogs(actual, expected)
    compare_attributes([:name, :environment, :tags, :classes], actual, expected) and
    compare_resources(actual, expected) and
    compare_relationships(actual, expected)
  end

  def compare_attributes(attributes, actual, expected)
    attributes.all? do |attribute|
      actual.send(attribute) == expected.send(attribute)
    end
  end

  def compare_relationships(actual, expected)
    actual   = actual.edges.sort_by   { |r| r.to_s }
    expected = expected.edges.sort_by { |r| r.to_s }

    [:source, :target, :event, :callback].all? do |attribute|
      actual.map(&attribute) == expected.map(&attribute)
    end
  end

  def compare_resources(actual, expected)
    actual   = actual.resources.sort_by   { |r| r.name }
    expected = expected.resources.sort_by { |r| r.name }

    actual == expected
  end
end

