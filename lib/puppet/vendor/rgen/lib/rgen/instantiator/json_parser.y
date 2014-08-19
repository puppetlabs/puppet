class JsonParser

rule

  json: value { result = val[0] }

  array: "[" valueList "]" { result = val[1] }
    | "[" "]" { result = [] }

  valueList: value { result = [ val[0] ] }
    | value "," valueList { result = [ val[0] ] + val[2] }

  object: "{" memberList "}" { result = @instantiator.createObject(val[1]) }
    | "{" "}" { result = nil }

  memberList: member { result = val[0] }
    | member "," memberList { result = val[0].merge(val[2]) } 

  member: STRING ":" value { result = {val[0].value => val[2]} }

  value: array { result = val[0] }
    | object { result = val[0] }
    | STRING { result = val[0].value }
    | INTEGER { result = val[0].value.to_i }
    | FLOAT { result = val[0].value.to_f }
    | "true" { result = true }
    | "false" { result = false }

end

---- header

module RGen

module Instantiator

---- inner

	ParserToken = Struct.new(:line, :file, :value)

  def initialize(instantiator)
    @instantiator = instantiator
  end
     	
	def parse(str, file=nil)
		@q = []
		line = 1
		
		until str.empty?
			case str
				when /\A\n/
					str = $'
					line +=1
				when /\A\s+/
					str = $'
				when /\A([-+]?\d+\.\d+)/
					str = $'
					@q << [:FLOAT, ParserToken.new(line, file, $1)]
				when /\A([-+]?\d+)/
					str = $'
					@q << [:INTEGER, ParserToken.new(line, file, $1)]
				when /\A"((?:[^"\\]|\\"|\\\\|\\[^"\\])*)"/
					str = $'
          sval = $1
          sval.gsub!('\\\\','\\')
          sval.gsub!('\\"','"')
          sval.gsub!('\\n',"\n")
          sval.gsub!('\\r',"\r")
          sval.gsub!('\\t',"\t")
          sval.gsub!('\\f',"\f")
          sval.gsub!('\\b',"\b")
					@q << [:STRING, ParserToken.new(line, file, sval)]
				when /\A(\{|\}|\[|\]|,|:|true|false)/
					str = $'
					@q << [$1, ParserToken.new(line, file, $1)]
        else
          raise "parse error in line #{line} on "+str[0..20].inspect+"..."
			end
		end
		@q.push [false, ParserToken.new(line, file, '$end')]
		do_parse
	end
	
	def next_token
		r = @q.shift
    r
	end
	
---- footer

end

end

