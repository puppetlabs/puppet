require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe SafeYAML::Transform::ToDate do
  it "returns true when the value matches a valid Date" do
    subject.transform?("2013-01-01").should == [true, Date.parse("2013-01-01")]
  end

  it "returns false when the value does not match a valid Date" do
    subject.transform?("foobar").should be_false
  end

  it "returns false when the value does not end with a Date" do
    subject.transform?("2013-01-01\nNOT A DATE").should be_false
  end

  it "returns false when the value does not begin with a Date" do
    subject.transform?("NOT A DATE\n2013-01-01").should be_false
  end

  it "correctly parses the remaining formats of the YAML spec" do
    equivalent_values = [
      "2001-12-15T02:59:43.1Z", # canonical
      "2001-12-14t21:59:43.10-05:00", # iso8601
      "2001-12-14 21:59:43.10 -5", # space separated
      "2001-12-15 2:59:43.10" # no time zone (Z)
    ]

    equivalent_values.each do |value|
      success, result = subject.transform?(value)
      success.should be_true
      result.should == Time.utc(2001, 12, 15, 2, 59, 43, 100000)
    end
  end
end
