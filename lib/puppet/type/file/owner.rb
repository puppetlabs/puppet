module Puppet
  Puppet::Type.type(:file).newproperty(:owner) do

    desc "To whom the file should belong.  Argument can be user name or
      user ID."
    @event = :file_changed

    def insync?(current)
      provider.is_owner_insync?(current, @should)
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.id2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue = @should)
      case newvalue
      when Symbol
        newvalue.to_s
      when Integer
        provider.id2name(newvalue) || newvalue
      when String
        newvalue
      else
        raise Puppet::DevError, "Invalid uid type #{newvalue.class}(#{newvalue})"
      end
    end

    def retrieve
      if self.should
        @should = @should.collect do |val|
          unless val.is_a?(Integer)
            if tmp = provider.validuser?(val)
              val = tmp
            else
              raise "Could not find user #{val}"
            end
          else
            val
          end
        end
      end
      provider.retrieve(@resource)
    end

    def sync
      provider.sync(resource[:path], resource[:links], @should)
    end
  end
end

