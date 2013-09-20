require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe SafeYAML::Transform do
  it "should return the same encoding when decoding Base64" do
    value = "c3VyZS4="
    decoded = SafeYAML::Transform.to_proper_type(value, false, "!binary")

    decoded.should == "sure."
    decoded.encoding.should == value.encoding if decoded.respond_to?(:encoding)
  end
end
