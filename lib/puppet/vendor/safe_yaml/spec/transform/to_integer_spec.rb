require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe SafeYAML::Transform::ToInteger do
  it "returns true when the value matches a valid Integer" do
    subject.transform?("10").should == [true, 10]
  end

  it "returns false when the value does not match a valid Integer" do
    subject.transform?("foobar").should be_false
  end

  it "returns false when the value spans multiple lines" do
    subject.transform?("10\nNOT AN INTEGER").should be_false
  end

  it "allows commas in the number" do
    subject.transform?("1,000").should == [true, 1000]
  end

  it "correctly parses numbers in octal format" do
    subject.transform?("010").should == [true, 8]
  end

  it "correctly parses numbers in hexadecimal format" do
    subject.transform?("0x1FF").should == [true, 511]
  end

  it "defaults to a string for a number that resembles octal format but is not" do
    subject.transform?("09").should be_false
  end

  it "correctly parses 0 in decimal" do
    subject.transform?("0").should == [true, 0]
  end

  it "defaults to a string for a number that resembles hexadecimal format but is not" do
    subject.transform?("0x1G").should be_false
  end

  it "correctly parses all formats in the YAML spec" do
    # canonical
    subject.transform?("685230").should == [true, 685230]

    # decimal
    subject.transform?("+685_230").should == [true, 685230]

    # octal
    subject.transform?("02472256").should == [true, 685230]

    # hexadecimal:
    subject.transform?("0x_0A_74_AE").should == [true, 685230]

    # binary
    subject.transform?("0b1010_0111_0100_1010_1110").should == [true, 685230]

    # sexagesimal
    subject.transform?("190:20:30").should == [true, 685230]
  end
end
