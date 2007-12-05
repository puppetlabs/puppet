#This is an example of using RSpec's expectations in test/unit.
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require 'test/unit'
require 'spec/test_case_adapter'

class IntegratingRSpecExpectationsIntoTestCaseTest < Test::Unit::TestCase

  def test_should_support_rspecs_equality_expectations
    5.should == 5
  end

  def test_should_support_rspecs_comparison_expectations
    5.should be > 4
  end
  
  class Band
    def players
      ["John", "Paul", "George", "Ringo"]
    end
  end

  def test_should_support_rspecs_collection_expectations
    Band.new.should have(4).players
  end
end
