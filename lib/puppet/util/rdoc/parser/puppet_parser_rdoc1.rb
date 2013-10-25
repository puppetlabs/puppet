require 'puppet/util/rdoc/parser/puppet_parser_core.rb'

module RDoc
  PUPPET_RDOC_VERSION = 1

  # @api private
  class PuppetParserRDoc1
    extend ParserFactory
    include PuppetParserCore

    def create_rdoc_preprocess
      preprocess = SM::PreProcess.new(@input_file_name, @options.rdoc_include)
    end
  end

  # For backwards compatibility
  # @api private
  Parser = PuppetParserRDoc1
end
