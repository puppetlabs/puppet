# If you make changes to this file, regenerate the pcore resource type using
# bundle exec puppet generate types --environmentpath spec/fixtures/integration/application/apply/environments -E spec
Puppet::Type.newtype(:applytest) do
  newproperty(:message) do
    def sync
      Puppet.send(@resource[:loglevel], self.should)
    end

    def retrieve
      :absent
    end

    def insync?(is)
      false
    end

    defaultto { @resource[:name] }
  end

  newparam(:name) do
    desc "An arbitrary tag for your own reference; the name of the message."
    Puppet.notice('the Puppet::Type says hello')
    isnamevar
  end
end
