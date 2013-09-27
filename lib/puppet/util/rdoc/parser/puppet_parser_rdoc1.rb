require 'puppet/util/rdoc/parser/puppet_parser_core.rb'


class RDoc::PuppetParserRDoc1
  extend RDoc::ParserFactory
  include RDoc::PuppetParserCore

  def create_rdoc_preprocess
    preprocess = SM::PreProcess.new(@input_file_name, @options.rdoc_include)
  end
end
