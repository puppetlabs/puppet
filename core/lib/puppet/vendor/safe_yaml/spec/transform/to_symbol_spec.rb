require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe SafeYAML::Transform::ToSymbol do
  def with_symbol_deserialization_value(value)
    symbol_deserialization_flag = SafeYAML::OPTIONS[:deserialize_symbols]
    SafeYAML::OPTIONS[:deserialize_symbols] = value

    yield

  ensure
    SafeYAML::OPTIONS[:deserialize_symbols] = symbol_deserialization_flag
  end

  def with_symbol_deserialization(&block)
    with_symbol_deserialization_value(true, &block)
  end

  def without_symbol_deserialization(&block)
    with_symbol_deserialization_value(false, &block)
  end

  it "returns true when the value matches a valid Symbol" do
    with_symbol_deserialization { subject.transform?(":foo")[0].should be_true }
  end

  it "returns true when the value matches a valid String+Symbol" do
    with_symbol_deserialization { subject.transform?(':"foo"')[0].should be_true }
  end

  it "returns false when symbol deserialization is disabled" do
    without_symbol_deserialization { subject.transform?(":foo").should be_false }
  end

  it "returns false when the value does not match a valid Symbol" do
    with_symbol_deserialization { subject.transform?("foo").should be_false }
  end

  it "returns false when the symbol does not begin the line" do
    with_symbol_deserialization do
      subject.transform?("NOT A SYMBOL\n:foo").should be_false
    end
  end

  it "returns false when the symbol does not end the line" do
    with_symbol_deserialization do
      subject.transform?(":foo\nNOT A SYMBOL").should be_false
    end
  end
end
