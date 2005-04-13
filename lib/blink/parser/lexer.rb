#!/usr/local/bin/ruby -w

# $Id$

# the scanner/lexer

require 'strscan'
require 'blink'


module Blink
    class LexError < RuntimeError; end
    module Parser
        #---------------------------------------------------------------
        class Lexer
            attr_reader :line, :last, :file

            @@tokens = {
                %r{#.+} => :COMMENT,
                %r{\[} => :LBRACK,
                %r{\]} => :RBRACK,
                %r{\{} => :LBRACE,
                %r{\}} => :RBRACE,
                %r{\(} => :LPAREN,
                %r{\)} => :RPAREN,
                %r{"} => :DQUOTE,
                %r{\n} => :RETURN,
                %r{'} => :SQUOTE,
                %r{=} => :EQUALS,
                %r{,} => :COMMA,
                %r{\?} => :QMARK,
                %r{\\} => :BACKSLASH,
                %r{=>} => :FARROW,
                %r{\w+} => :WORD,
                %r{:\w+} => :SYMBOL
            }

            # scan the whole file
            # basically just used for testing
            def fullscan
                array = []

                self.scan { |token,str|
                    #Blink.debug("got token '%s' => '%s'" % [token,str])
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
                @skip = %r{\s+}
            end

            def rest
                @scanner.rest
            end

            # this is the heart of the lexer
            def scan
                Blink.debug("entering scan")
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
                            #blink.debug("did not match %s to '%s'" %
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
                        raise "Could not match '%s'" % @scanner.rest
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
                    when :COMMENT then
                        # just throw comments away
                    when :RETURN then
                        Blink.debug("one more line")
                        @line += 1
                        @scanner.skip(@skip)
                    when :DQUOTE then
                        #Blink.debug("searching '%s' after '%s'" % [self.rest,value])
                        value = self.slurpstring(value)
                        yield [:QTEXT,value]
                        @last = value
                        #stoken = :QTEXT
                        Blink.debug("got string '%s' => '%s'" % [:QTEXT,value])
                    when :SYMBOL then
                        value.sub!(/^:/,'')
                        yield [:QTEXT,value]
                        @last = value
                        Blink.debug("got token '%s' => '%s'" % [:QTEXT,value])
                    else
                        yield [stoken,value]
                        @last = value
                        Blink.debug("got token '%s' => '%s'" % [stoken,value])
                    end
                    @scanner.skip(@skip)
                end
                @scanner = nil
                yield [false,false]
            end

            # we've encountered an opening quote...
            # slurp in the rest of the string and return it
            def slurpstring(quote)
                #Blink.debug("searching '%s'" % self.rest)
                str = @scanner.scan_until(/[^\\]#{quote}/)
                #str = @scanner.scan_until(/"/)
                if str.nil?
                    raise Blink::LexError.new("Unclosed quote after '%s' in '%s'" %
                        [self.last,self.rest])
                else
                    str.sub!(/#{quote}$/,"")
                    str.gsub!(/\\#{quote}/,quote)
                end

                return str
            end

            def string=(string)
                @scanner = StringScanner.new(string)
            end
        end
        #---------------------------------------------------------------
    end
end
