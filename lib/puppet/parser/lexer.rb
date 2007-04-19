
# the scanner/lexer

require 'strscan'
require 'puppet'


module Puppet
    class LexError < RuntimeError; end
    module Parser
        #---------------------------------------------------------------
        class Lexer
            attr_reader :line, :last, :file

            attr_accessor :indefine

                #%r{\w+} => :WORD,
            @@tokens = {
                %r{#.*} => :COMMENT,
                %r{\[} => :LBRACK,
                %r{\]} => :RBRACK,
                %r{\{} => :LBRACE,
                %r{\}} => :RBRACE,
                %r{\(} => :LPAREN,
                %r{\)} => :RPAREN,
                %r{\"} => :DQUOTE,
                %r{\n} => :RETURN,
                %r{\'} => :SQUOTE,
                %r{=} => :EQUALS,
                %r{==} => :ISEQUAL,
                %r{>=} => :GREATEREQUAL,
                %r{>} => :GREATERTHAN,
                %r{<} => :LESSTHAN,
                %r{<=} => :LESSEQUAL,
                %r{!=} => :NOTEQUAL,
                %r{!} => :NOT,
                %r{,} => :COMMA,
                %r{\.} => :DOT,
                %r{:} => :COLON,
                %r{@} => :AT,
                %r{<<\|} => :LLCOLLECT,
                %r{\|>>} => :RRCOLLECT,
                %r{<\|} => :LCOLLECT,
                %r{\|>} => :RCOLLECT,
                %r{;} => :SEMIC,
                %r{\?} => :QMARK,
                %r{\\} => :BACKSLASH,
                %r{=>} => :FARROW,
                %r{[a-z][-\w]*} => :NAME,
                %r{([a-z][-\w]*::)+[a-z][-\w]*} => :CLASSNAME,
                %r{([A-Z][-\w]*::)+[A-Z][-\w]*} => :CLASSREF,
                %r{[A-Z][-\w]*} => :TYPE,
                %r{[0-9]+} => :NUMBER,
                %r{\$(\w*::)*\w+} => :VARIABLE
            }

            @@keywords = {
                "case" => :CASE,
                "class" => :CLASS,
                "default" => :DEFAULT,
                "define" => :DEFINE,
                "false" => :BOOLEAN,
                "import" => :IMPORT,
                "if" => :IF,
                "elsif" => :ELSIF,
                "else" => :ELSE,
                "inherits" => :INHERITS,
                "node" => :NODE,
                "true" => :BOOLEAN,
                "and"  => :AND,
                "or"   => :OR
            }

            def clear
                initvars
            end

            # scan the whole file
            # basically just used for testing
            def fullscan
                array = []

                self.scan { |token,str|
                    # Ignore any definition nesting problems
                    @indefine = false
                    #Puppet.debug("got token '%s' => '%s'" % [token,str])
                    if token.nil?
                        return array
                    else
                        array.push([token,str])
                    end
                }
                return array
            end

            # this is probably pretty damned inefficient...
            # it'd be nice not to have to load the whole file first...
            def file=(file)
                @file = file
                @line = 1
                File.open(file) { |of|
                    str = ""
                    of.each { |line| str += line }
                    @scanner = StringScanner.new(str)
                }
            end

            def indefine?
                if defined? @indefine
                    @indefine
                else
                    false
                end
            end

            def initialize
                initvars()
            end

            def initvars
                @line = 1
                @last = ""
                @lasttoken = nil
                @scanner = nil
                @file = nil
                # AAARRGGGG! okay, regexes in ruby are bloody annoying
                # no one else has "\n" =~ /\s/
                @skip = %r{[ \t]+}

                @namestack = []
                @indefine = false
            end

            # Go up one in the namespace.
            def namepop
                @namestack.pop
            end

            # Collect the current namespace.
            def namespace
                @namestack.join("::")
            end

            # This value might have :: in it, but we don't care -- it'll be
            # handled normally when joining, and when popping we want to pop
            # this full value, however long the namespace is.
            def namestack(value)
                @namestack << value
            end

            def rest
                @scanner.rest
            end

            # this is the heart of the lexer
            def scan
                #Puppet.debug("entering scan")
                if @scanner.nil?
                    raise TypeError.new("Invalid or empty string")
                end

                @scanner.skip(@skip)
                until @scanner.eos? do
                    yielded = false
                    sendbreak = false # gah, this is a nasty hack
                    stoken = nil
                    sregex = nil
                    value = ""

                    # first find out which type of token we've got
                    @@tokens.each { |regex,token|
                        # we're just checking, which doesn't advance the scan
                        # pointer
                        tmp = @scanner.check(regex)
                        if tmp.nil?
                            #puppet.debug("did not match %s to '%s'" %
                            #    [regex,@scanner.rest])
                            next
                        end

                        # find the longest match
                        if tmp.length > value.length
                            value = tmp 
                            stoken = token
                            sregex = regex
                        else
                            # we've already got a longer match
                            next
                        end
                    }

                    # error out if we didn't match anything at all
                    if stoken.nil?
                        nword = nil
                        if @scanner.rest =~ /^(\S+)/
                            nword = $1
                        elsif@scanner.rest =~ /^(\s+)/
                            nword = $1
                        else
                            nword = @scanner.rest
                        end
                        raise "Could not match '%s'" % nword
                    end

                    value = @scanner.scan(sregex)

                    if value == ""
                        raise "Didn't match regex on token %s" % stoken
                    end

                    # token-specific operations
                    # if this gets much more complicated, it should
                    # be moved up to where the tokens themselves are defined
                    # which will get me about 75% of the way to a lexer generator
                    ptoken = stoken
                    case stoken
                    when :NAME then
                        wtoken = stoken
                        # we're looking for keywords here
                        if @@keywords.include?(value)
                            wtoken = @@keywords[value]
                            #Puppet.debug("token '%s'" % wtoken)
                            if wtoken == :BOOLEAN
                                value = eval(value)
                            end
                        end
                        ptoken = wtoken
                    when :NUMBER then
                        ptoken = :NAME
                    when :COMMENT then
                        # just throw comments away
                        next
                    when :RETURN then
                        @line += 1
                        @scanner.skip(@skip)
                        next
                    when :SQUOTE then
                        #Puppet.debug("searching '%s' after '%s'" % [self.rest,value])
                        value = self.slurpstring(value)
                        ptoken = :SQTEXT
                        #Puppet.debug("got string '%s' => '%s'" % [:DQTEXT,value])
                    when :DQUOTE then
                        value = self.slurpstring(value)
                        ptoken = :DQTEXT
                    when :VARIABLE then
                        value = value.sub(/^\$/, '')
                    end

                    yield [ptoken, value]

                    if @lasttoken == :CLASS
                        namestack(value)
                    end

                    if @lasttoken == :DEFINE
                        if indefine?
                            msg = "Cannot nest definition %s inside %s" % [value, @indefine]
                            self.indefine = false
                            raise Puppet::ParseError, msg
                        end

                        @indefine = value
                    end

                    @last = value
                    @lasttoken = ptoken

                    @scanner.skip(@skip)
                end
                @scanner = nil
                yield [false,false]
            end

            # we've encountered an opening quote...
            # slurp in the rest of the string and return it
            def slurpstring(quote)
                # we search for the next quote that isn't preceded by a
                # backslash; the caret is there to match empty strings
                str = @scanner.scan_until(/([^\\]|^)#{quote}/)
                if str.nil?
                    raise Puppet::LexError.new("Unclosed quote after '%s' in '%s'" %
                        [self.last,self.rest])
                else
                    str.sub!(/#{quote}\Z/,"")
                    str.gsub!(/\\#{quote}/,quote)
                end

                return str
            end

            # just parse a string, not a whole file
            def string=(string)
                @scanner = StringScanner.new(string)
            end
        end
        #---------------------------------------------------------------
    end
end

# $Id$
