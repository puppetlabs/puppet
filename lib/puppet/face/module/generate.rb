Puppet::Face.define(:module, '1.0.0') do
  action(:generate) do
    summary _("Generate boilerplate for a new module.")
    #TRANSLATORS 'Puppet Development Kit' is the name of the software package replacing this action and should not be translated.
    description _("This action has been replaced by Puppet Development Kit. For more information visit https://puppet.com/docs/pdk/latest/pdk.html.")

    when_invoked do |*args|
      #TRANSLATORS 'Puppet Development Kit' is the name of the software package replacing this action and should not be translated.
      raise _("This action has been replaced by Puppet Development Kit. For more information visit https://puppet.com/docs/pdk/latest/pdk.html.")
    end

    deprecate
  end
end
