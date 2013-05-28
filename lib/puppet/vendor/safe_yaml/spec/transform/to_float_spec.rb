require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe SafeYAML::Transform::ToFloat do
  it "returns true when the value matches a valid Float" do
    subject.transform?("20.00").should == [true, 20.0]
  end

  it "returns false when the value does not match a valid Float" do
    subject.transform?("foobar").should be_false
  end

  it "returns false when the value spans multiple lines" do
    subject.transform?("20.00\nNOT A FLOAT").should be_false
  end

  it "correctly parses all formats in the YAML spec" do
    # canonical
    subject.transform?("6.8523015e+5").should == [true, 685230.15]

    # exponentioal
    subject.transform?("685.230_15e+03").should == [true, 685230.15]

    # fixed
    subject.transform?("685_230.15").should == [true, 685230.15]

    # sexagesimal
    subject.transform?("190:20:30.15").should == [true, 685230.15]

    # infinity
    subject.transform?("-.inf").should == [true, (-1.0 / 0.0)]

    # not a number
    # NOTE: can't use == here since NaN != NaN
    success, result = subject.transform?(".NaN")
    success.should be_true; result.should be_nan
  end

  # issue 29
  it "returns false for the string '.'" do
    subject.transform?(".").should be_false
  end
end
