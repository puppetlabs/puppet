require File.dirname(__FILE__) + '/../../../spec_helper.rb'

module Spec
module Runner
module Formatter
describe "SpecdocFormatterDryRun" do
    before(:each) do
        @io = StringIO.new
        @formatter = SpecdocFormatter.new(@io)
        @formatter.dry_run = true
    end
    it "should not produce summary on dry run" do
        @formatter.dump_summary(3, 2, 1, 0)
        @io.string.should eql("")
      
    end
  
end
end
end
end
