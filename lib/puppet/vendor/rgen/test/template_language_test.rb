$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/template_language'
require 'rgen/metamodel_builder'

class TemplateContainerTest < Test::Unit::TestCase
  
  TEMPLATES_DIR = File.dirname(__FILE__)+"/template_language_test/templates"
  OUTPUT_DIR = File.dirname(__FILE__)+"/template_language_test"
  
  module MyMM
    
    class Chapter
      attr_reader :title
      def initialize(title)
        @title = title
      end
    end
    
    class Document
      attr_reader :title, :authors, :chapters
      attr_accessor :sampleArray
      def initialize(title)
        @title = title
        @chapters = []
        @authors = []
      end
    end
    
    class Author
      attr_reader :name, :email
      def initialize(name, email)
        @name, @email = name, email
      end      
    end
    
  end
  
  module CCodeMM
    class CArray < RGen::MetamodelBuilder::MMBase
      has_attr 'name'
      has_attr 'size', Integer
      has_attr 'type'
    end
    class PrimitiveInitValue < RGen::MetamodelBuilder::MMBase
      has_attr 'value', Integer
    end
    CArray.has_many 'initvalue', PrimitiveInitValue
  end
  
  TEST_MODEL = MyMM::Document.new("SomeDocument")
  TEST_MODEL.authors << MyMM::Author.new("Martin", "martin@somewhe.re")
  TEST_MODEL.authors << MyMM::Author.new("Otherguy", "other@somewhereel.se")
  TEST_MODEL.chapters << MyMM::Chapter.new("Intro")
  TEST_MODEL.chapters << MyMM::Chapter.new("MainPart")
  TEST_MODEL.chapters << MyMM::Chapter.new("Summary")
  TEST_MODEL.sampleArray = CCodeMM::CArray.new(:name => "myArray", :type => "int", :size => 5,
    :initvalue => (1..5).collect { |v| CCodeMM::PrimitiveInitValue.new(:value => v) })
  
  def test_with_model
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    File.delete(OUTPUT_DIR+"/testout.txt") if File.exists? OUTPUT_DIR+"/testout.txt"
    tc.expand('root::Root', :for => TEST_MODEL, :indent => 1)
    result = expected = ""
    File.open(OUTPUT_DIR+"/testout.txt") {|f| result = f.read}
	    File.open(OUTPUT_DIR+"/expected_result1.txt") {|f| expected = f.read}
    assert_equal expected, result
  end
  
  def test_immediate_result
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    expected = ""
    File.open(OUTPUT_DIR+"/expected_result2.txt","rb") {|f| expected = f.read}
    assert_equal expected, tc.expand('code/array::ArrayDefinition', :for => TEST_MODEL.sampleArray).to_s
  end
  
  def test_indent_string
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    tc.indentString = "  "  # 2 spaces instead of 3 (default)
    tc.expand('indent_string_test::IndentStringTest', :for => :dummy)
    File.open(OUTPUT_DIR+"/indentStringTestDefaultIndent.out","rb") do |f|
      assert_equal "  <- your default here\r\n", f.read
    end
    File.open(OUTPUT_DIR+"/indentStringTestTabIndent.out","rb") do |f|
      assert_equal "\t<- tab\r\n", f.read
    end
  end
  
  def test_null_context
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_raise StandardError do 
      # the template must raise an exception because it calls expand :for => nil
      tc.expand('null_context_test::NullContextTestBad', :for => :dummy)
    end
    assert_raise StandardError do 
      # the template must raise an exception because it calls expand :foreach => nil
      tc.expand('null_context_test::NullContextTestBad2', :for => :dummy)
    end
    assert_nothing_raised do
      tc.expand('null_context_test::NullContextTestOk', :for => :dummy)
    end
  end
  
  def test_no_indent
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal "   xxx<---\r\n   xxx<---\r\n   xxx<---\r\n   xxx<---\r\n", tc.expand('no_indent_test/test::Test', :for => :dummy)
  end
  
  def test_no_indent2
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal "      return xxxx;\r\n", tc.expand("no_indent_test/test2::Test", :for => :dummy)
  end
  
  def test_no_indent3
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal "   l1<---\r\n   l2\r\n\r\n", tc.expand("no_indent_test/test3::Test", :for => :dummy)
  end
  
  def test_template_resolution
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal "Sub1\r\nSub1 in sub1\r\n", tc.expand('template_resolution_test/test::Test', :for => :dummy)
    assert_equal "Sub1\r\nSub1\r\nSub1 in sub1\r\n", tc.expand('template_resolution_test/sub1::Test', :for => :dummy)
  end
  
  def test_evaluate
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal "xx1xxxx2xxxx3xxxx4xx\r\n", tc.expand('evaluate_test/test::Test', :for => :dummy)
  end
  
  def test_define_local
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal "Local1\r\n", tc.expand('define_local_test/test::Test', :for => :dummy)
    assert_raise StandardError do
      tc.expand('define_local_test/test::TestForbidden', :for => :dummy)
    end
  end

  def test_no_backslash_r
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    expected = ""
    File.open(OUTPUT_DIR+"/expected_result3.txt") {|f| expected = f.read}
    assert_equal expected, tc.expand('no_backslash_r_test::Test', :for => :dummy).to_s
  end

  def test_callback_indent
    tc = RGen::TemplateLanguage::DirectoryTemplateContainer.new([MyMM, CCodeMM], OUTPUT_DIR)
    tc.load(TEMPLATES_DIR)
    assert_equal("|before callback\r\n   |in callback\r\n|after callback\r\n   |after iinc\r\n",
     tc.expand('callback_indent_test/a::caller', :for => :dummy))
  end
end
