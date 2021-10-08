require 'spec_helper'

RSpec.shared_context('l10n') do |locale|
  before :all do
    @old_locale = Locale.current
    Locale.current = locale

    @old_gettext_disabled = Puppet::GettextConfig.instance_variable_get(:@gettext_disabled)
    Puppet::GettextConfig.instance_variable_set(:@gettext_disabled, false)
    Puppet::GettextConfig.setup_locale
    Puppet::GettextConfig.create_default_text_domain

    # overwrite stubs with real implementation
    ::Object.send(:remove_method, :_)
    ::Object.send(:remove_method, :n_)
    class ::Object
      include FastGettext::Translation
    end
  end

  after :all do
    Locale.current = @old_locale

    Puppet::GettextConfig.instance_variable_set(:@gettext_disabled, @old_gettext_disabled)
    # restore stubs
    load File.expand_path(File.join(__dir__, '../../lib/puppet/gettext/stubs.rb'))
  end

  before :each do
    Puppet[:disable_i18n] = false
  end
end
