$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/template_language/output_handler'

class MetamodelBuilderTest < Test::Unit::TestCase
	def test_direct_nl
		h = RGen::TemplateLanguage::OutputHandler.new
		h.mode = :direct
		h << "Test"
		h.ignoreNextNL
		h << "\nContent"
		assert_equal "TestContent", h.to_s
	end
	def test_direct_ws
		h = RGen::TemplateLanguage::OutputHandler.new
		h.mode = :direct
		h << "Test"
		h.ignoreNextWS
		h << " \n       Content"
		assert_equal "TestContent", h.to_s
	end
	def test_explicit_indent
		h = RGen::TemplateLanguage::OutputHandler.new
		h.mode = :explicit
		h.indent = 1
		h << "Start"
		h << "   \n "
		h << "Test"
		h << "      \n   \n    Content"
		assert_equal "   Start\n   Test\n   Content", h.to_s
	end
	def test_explicit_endswithws
		h = RGen::TemplateLanguage::OutputHandler.new
		h.mode = :explicit
		h.indent = 1
		h << "Start   \n\n"
		assert_equal "   Start\n", h.to_s
	end
  def test_performance
    h = RGen::TemplateLanguage::OutputHandler.new
    h.mode = :explicit
    h.indent = 1
    line = (1..50).collect{|w| "someword"}.join(" ")+"\n"
    # repeat more often to make performance differences visible
    20.times do 
      h << line
    end
  end
	def test_indent_string
		h = RGen::TemplateLanguage::OutputHandler.new(1, "\t", :explicit)
		h << "Start"
		h << "   \n "
		h << "Test"
		h << "      \n   \n    Content"
		assert_equal "\tStart\n\tTest\n\tContent", h.to_s
	end
end