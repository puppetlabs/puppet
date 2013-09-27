require 'puppet/util/rdoc/parser/puppet_parser_core.rb'

class RDoc::PuppetParserRDoc2 < ::RDoc::Parser
  include RDoc::PuppetParserCore

  def create_rdoc_preprocess
    preprocess = RDoc::Markup::PreProcess.new(@input_file_name, @options.rdoc_include)
  end
end
