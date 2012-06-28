
module Puppet
  module DSL
    if RUBY_VERSION < "1.9"
      class BlankSlate
        instance_methods.each do |m|
          unless [:==, :equal?, :'!', :'!=', :instance_eval, :instance_exec,
                  :__send__, :__id__].include? m
            undef_method m
          end
        end
      end
    else
      class BlankSlate < BasicObject

        def self.const_missing(name)
          ::Object.const_get(name)
        end
      end
    end
  end
end

