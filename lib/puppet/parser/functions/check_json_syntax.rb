# Validates a string containing Json
Puppet::Parser::Functions::newfunction(
  :check_json_syntax, :arity => -3, :type => :rvalue,
  :doc => <<-'ENDHEREDOC') do |args|
  Validates a string in JSON format. This function can be called with a single string with the content to check and
  a string containing the syntax specification (which may consist of several segments separated by `+`).

  This function is also used as a heredoc-checker if a heredoc is written on the format `@(END:json)`.acceptor.

  When used from Ruby the third argument should be an instance of Puppet::Pops::Validator::Acceptor and the fourth
  argument a hash with keys file, line and pos set to the location values to use when reporting issues.

  This function typically only issues a single error for the first found issue when parsing the given JSON text.
  ENDHEREDOC

  require 'puppet/pops'
  require 'json'

  str = args[0]

  raise ArgumentError.new("check_json_syntax(): first argument must be a string.") unless str.is_a?(String)
  if args.size > 1
    syntax = args[1]
    acceptor = args[2]
    info = args[3]
    raise ArgumentError.new("check_json_syntax(): second argument must be a syntax string e.g. json, data+json") unless syntax.is_a?(String)
    raise ArgumentError.new("check_json_syntax(): second argument must be an Acceptor.") unless acceptor.is_a?(Puppet::Pops::Validation::Acceptor)
    raise ArgumentError.new("check_json_syntax(): third argument must be a Hash with information.") unless info.is_a?(Hash)
  end

  begin
    JSON.parse(str)
  rescue => e
    # Cap the message to 100 chars and replace newlines
    msg = "check_json_syntax(): Cannot parse invalid JSON string. \"#{e.message().slice(0,100).gsub(/\r?\n/, "\\n")}\""
    if args.size != 4
      # When called from a manifest, source location is picked up by ParseError
      raise Puppet::ParseError.new(msg)
    end

    # This API is not great when calling from non Pops logic
    # TODO: improve the pops API to allow simpler diagnostic creation while still maintaining capabilities
    # and the issue code. (In this case especially, where there is only a single error message being issued).
    #
    issue = Puppet::Pops::Issues::issue(:ILLEGAL_JSON) { msg }
    source_pos = Puppet::Pops::Adapters::SourcePosAdapter.new()
    source_pos.line = info[:line]
    source_pos.pos = info[:pos]
    acceptor.accept(Puppet::Pops::Validation::Diagnostic.new(:error, issue, info[:file], source_pos, {}))
  end
end
