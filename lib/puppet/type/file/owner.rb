module Puppet
  Puppet::Type.type(:file).newproperty(:owner) do
    include Puppet::Util::Warnings

    desc "To whom the file should belong.  Argument can be user name or
      user ID."

    def insync?(current)
      # We don't want to validate/munge users until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.
      @should.map! do |val|
        provider.name2uid(val) or raise "Could not find user #{val}"
      end

      return true if @should.include?(current)

      unless Puppet.features.root?
        warnonce "Cannot manage ownership unless running as root"
        return true
      end

      false
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.uid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.uid2name(newvalue) || newvalue
    end
  end
end

