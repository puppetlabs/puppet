require 'puppet/util/rdoc/parser/puppet_parser_core.rb'

module RDoc
  PUPPET_RDOC_VERSION = 2

  # @api private
  class PuppetParserRDoc2 < Parser
    include PuppetParserCore

    def create_rdoc_preprocess
      Markup::PreProcess.new(@input_file_name, @options.rdoc_include)
    end
  end
end
