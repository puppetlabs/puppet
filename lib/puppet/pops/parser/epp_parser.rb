# The EppParser is a specialized Puppet Parser that starts parsing in Epp Text mode
class Puppet::Pops::Parser::EppParser < Puppet::Pops::Parser::Parser

  # Initializes the epp parser support by creating a new instance of {Puppet::Pops::Parser::Lexer}
  # configured to start in Epp Lexing mode.
  # @return [void]
  #
  def initvars
    self.lexer = Puppet::Pops::Parser::Lexer.new({:mode => :epp})
  end

  # Parses a file expected to contain epp text/DSL logic.
  def parse_file(file)
    unless FileTest.exist?(file)
      unless file =~ /\.epp$/
        file = file + ".epp"
      end
    end
    @lexer.file = file
    _parse()
  end
end
