#
# Monkey patches to ruby classes for compatibility
#
#
# In earlier versions of ruby (e.g. 1.8.1) yaml serialized symbols with an explicit
# type designation.  Later versions understand the explicit form in addition to the
# implicit "literal" form (e.g. :symbol) which they produce.
#
# This causes problems when the puppet master and the client are running on different
# versions of ruby; the newer version can produce yaml that it's older partner can't 
# decypher.
#
# This patch causes newer versions to produce the older encoding for Symbols.  It is
# only applied if the existing library does not already produce them.  Thus it will
# not be applied on older rubys and it will not be applied more than once.  It also 
# checks that it has been applied to a version which support it and, if not reverts
# to the original.
#
require "yaml"

if :test.to_yaml !~ %r{!ruby/sym}
    class Symbol
        if !respond_to? :original_to_yaml
            alias :original_to_yaml :to_yaml
            def to_yaml(opts={})
                YAML::quick_emit(nil,opts) { |out|
                    if out.respond_to? :scalar
                        # 1.8.5 through 1.8.8, possibly others
                        out.scalar("tag:ruby:sym", to_s,:to_yaml_style)
                    elsif out.respond_to? :<<
                        # 1.8.2, possibly others
                        out << "!ruby/sym "
                        self.id2name.to_yaml( :Emitter => out )
                    else
                        # go back to the base version if neither of the above work
                        alias :to_yaml :original_to_yaml
                        to_yaml(opts)
                    end
                }
            end    
        end
    end
end
