require "#{File.dirname(__FILE__)}/../../spec_helper"

describe "The bin/spec script" do
  it "should have no warnings" do
    spec_path = "#{File.dirname(__FILE__)}/../../../bin/spec"
    output = nil
    IO.popen("ruby -w #{spec_path} --help 2>&1") do |io|
      output = io.read
    end
    output.should_not =~ /warning/n
  end
end
