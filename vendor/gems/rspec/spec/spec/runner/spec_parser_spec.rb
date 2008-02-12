require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "c" do

  it "1" do
  end

  it "2" do
  end

end

describe "d" do

  it "3" do
  end

  it "4" do
  end

end

class SpecParserSubject
end

describe SpecParserSubject do
  
  it "5" do
  end
  
end

describe SpecParserSubject, "described" do
  
  it "6" do
  end
  
end

describe "SpecParser" do
  before(:each) do
    @p = Spec::Runner::SpecParser.new
  end

  it "should find spec name for 'specify' at same line" do
    @p.spec_name_for(File.open(__FILE__), 5).should == "c 1"
  end

  it "should find spec name for 'specify' at end of spec line" do
    @p.spec_name_for(File.open(__FILE__), 6).should == "c 1"
  end

  it "should find context for 'context' above all specs" do
    @p.spec_name_for(File.open(__FILE__), 4).should == "c"
  end

  it "should find spec name for 'it' at same line" do
    @p.spec_name_for(File.open(__FILE__), 15).should == "d 3"
  end

  it "should find spec name for 'it' at end of spec line" do
    @p.spec_name_for(File.open(__FILE__), 16).should == "d 3"
  end

  it "should find context for 'describe' above all specs" do
    @p.spec_name_for(File.open(__FILE__), 14).should == "d"
  end

 it "should find nearest example name between examples" do
   @p.spec_name_for(File.open(__FILE__), 7).should == "c 1"
 end

  it "should find nothing outside a context" do
    @p.spec_name_for(File.open(__FILE__), 2).should be_nil
  end
  
  it "should find context name for type" do
    @p.spec_name_for(File.open(__FILE__), 26).should == "SpecParserSubject"
  end
  
  it "should find context and spec name for type" do
    @p.spec_name_for(File.open(__FILE__), 28).should == "SpecParserSubject 5"
  end

  it "should find context and description for type" do
    @p.spec_name_for(File.open(__FILE__), 33).should == "SpecParserSubject described"
  end
  
  it "should find context and description and example for type" do
    @p.spec_name_for(File.open(__FILE__), 36).should == "SpecParserSubject described 6"
  end
  
end
