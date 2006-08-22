
# the scanner/lexer

require 'strscan'
require 'puppet'


module Puppet
    class LexError < RuntimeError; end
    module Parser
        #---------------------------------------------------------------
        class Lexer
            attr_reader :line, :last, :file

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
                %r{,} => :COMMA,
                %r{\.} => :DOT,
                %r{:} => :COLON,
                %r{@} => :AT,
                %r{<\|} => :LCOLLECT,
                %r{\|>} => :RCOLLECT,
                %r{;} => :SEMIC,
                %r{\?} => :QMARK,
                %r{\\} => :BACKSLASH,
                %r{=>} => :FARROW,
                %r{[a-z][-\w]*} => :NAME,
                %r{[A-Z][-\w]*} => :TYPE,
                %r{[0-9]+} => :NUMBER,
                %r{\$\w+} => :VARIABLE
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
                "true" => :BOOLEAN
            }

            # scan the whole file
            # basically just used for testing
            def fullscan
                array = []

                self.scan { |token,str|
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

            def initialize
                @line = 1
                @last = ""
                @scanner = nil
                @file = nil
                # AAARRGGGG! okay, regexes in ruby are bloody annoying
                # no one else has "\n" =~ /\s/
                @skip = %r{[ \t]+}
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
                    case stoken
                    when :NAME then
                        wtoken = stoken
                        # we're looking for keywords here
                        if @@keywords.include?(value)
                            wtoken = @@keywords[value]
                            #Puppet.debug("token '%s'" % wtoken)
                        end
                        yield [wtoken,value]
                        @last = value
                    when :NUMBER then
                        yield [:NAME,value]
                        # just throw comments away
                    when :COMMENT then
                        # just throw comments away
                    when :RETURN then
                        @line += 1
                        @scanner.skip(@skip)
                    when :SQUOTE then
                        #Puppet.debug("searching '%s' after '%s'" % [self.rest,value])
                        value = self.slurpstring(value)
                        yield [:SQTEXT,value]
                        @last = value
                        #stoken = :DQTEXT
                        #Puppet.debug("got string '%s' => '%s'" % [:DQTEXT,value])
                    when :DQUOTE then
                        #Puppet.debug("searching '%s' after '%s'" % [self.rest,value])
                        value = self.slurpstring(value)
                        yield [:DQTEXT,value]
                        @last = value
                        #stoken = :DQTEXT
                        #Puppet.debug("got string '%s' => '%s'" % [:DQTEXT,value])
                    else
                        #Puppet.debug("got token '%s' => '%s'" % [stoken,value])
                        yield [stoken,value]
                        @last = value
                    end
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
