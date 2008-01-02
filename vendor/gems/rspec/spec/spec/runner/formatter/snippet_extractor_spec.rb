require File.dirname(__FILE__) + '/../../../spec_helper.rb'

describe Spec::Runner::Formatter::SnippetExtractor do
  it "should fall back on a default message when it doesn't understand a line" do
    Spec::Runner::Formatter::SnippetExtractor.new.snippet_for("blech").should == ["# Couldn't get snippet for blech", 1]
  end

  it "should fall back on a default message when it doesn't find the file" do
    Spec::Runner::Formatter::SnippetExtractor.new.lines_around("blech", 8).should == "# Couldn't get snippet for blech"
  end
end
