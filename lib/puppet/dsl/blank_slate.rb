
module Puppet
  module DSL
    if RUBY_VERSION < "1.9"
      class BlankSlate
        instance_methods.each do |m|
          undef_method m unless m =~ /^__/ or m =~ /instance_eval/ or m =~ /object_id/ or m =~ /send/
        end
      end
    else
      class BlankSlate < BasicObject; end
    end
  end
end

