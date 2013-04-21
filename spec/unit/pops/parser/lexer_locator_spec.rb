require 'spec_helper'
require 'puppet/pops'


describe 'Puppet::Pops::Parser::Lexer::Locator' do
  before :all do
    @multibyte = Puppet::Pops::Parser::Lexer.new().multibyte?

  end
  context 'when computing line from offset' do
    it "should report lines correctly when leading is all 0" do
      locator = Puppet::Pops::Parser::Lexer::Locator.new("012\n012\n012\n", @multibyte)
      locator.line_for_offset(0).should == 1
      locator.line_for_offset(2).should == 1
      locator.line_for_offset(3).should == 1
      locator.line_for_offset(4).should == 2
      locator.line_for_offset(6).should == 2
      locator.line_for_offset(8).should == 3
      locator.line_for_offset(10).should == 3
      locator.line_for_offset(11).should == 3
      locator.line_for_offset(12).should == 4
    end
    it "should report lines correctly when leading line is not 0" do
      leading_line_count = 10
      leading_offset = 100
      leading_line_offset = 0
      locator = Puppet::Pops::Parser::Lexer::Locator.new("012\n012\n012\n", @multibyte, leading_line_count, leading_offset, leading_line_offset)
      locator.line_for_offset(0).should == 11
      locator.line_for_offset(2).should == 11
      locator.line_for_offset(3).should == 11
      locator.line_for_offset(4).should == 12
      locator.line_for_offset(6).should == 12
      locator.line_for_offset(8).should == 13
      locator.line_for_offset(10).should == 13
      locator.line_for_offset(11).should == 13
      locator.line_for_offset(12).should == 14
    end
  end
  context 'when computing position on line' do
    it "should report pos correctly when leading is all 0" do
      locator = Puppet::Pops::Parser::Lexer::Locator.new("012\n012\n012\n", @multibyte)
      locator.pos_on_line(0).should == 1
      locator.pos_on_line(1).should == 2
      locator.pos_on_line(2).should == 3
      locator.pos_on_line(3).should == 4
      locator.pos_on_line(4).should == 1
      locator.pos_on_line(5).should == 2
      locator.pos_on_line(6).should == 3
      locator.pos_on_line(7).should == 4
      locator.pos_on_line(8).should == 1
      locator.pos_on_line(9).should == 2
      locator.pos_on_line(10).should == 3
      locator.pos_on_line(11).should == 4
      locator.pos_on_line(12).should == 1
    end
    it "should report pos correctly when leading per line is not 0" do
      leading_line_count = 10
      leading_offset = 100
      leading_line_offset = 4
      locator = Puppet::Pops::Parser::Lexer::Locator.new("012\n012\n012\n", @multibyte, leading_line_count, leading_offset, leading_line_offset)
      locator.pos_on_line(0).should == 5
      locator.pos_on_line(1).should == 6
      locator.pos_on_line(2).should == 7
      locator.pos_on_line(3).should == 8
      locator.pos_on_line(4).should == 5
      locator.pos_on_line(5).should == 6
      locator.pos_on_line(6).should == 7
      locator.pos_on_line(7).should == 8
      locator.pos_on_line(8).should == 5
      locator.pos_on_line(9).should == 6
      locator.pos_on_line(10).should == 7
      locator.pos_on_line(11).should == 8
      locator.pos_on_line(12).should == 5
    end
  end

end