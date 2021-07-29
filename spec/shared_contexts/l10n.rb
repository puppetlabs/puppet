require 'spec_helper'

RSpec.shared_context('l10n') do |locale|
  before :all do
    @old_locale = Locale.current
    Locale.current = locale
    Puppet::GettextConfig.setup_locale

    # overwrite stubs with real implementation
    ::Object.send(:remove_method, :_)
    ::Object.send(:remove_method, :n_)
    class ::Object
      include FastGettext::Translation
    end
  end

  after :all do
    Locale.current = @old_locale

    # restore stubs
    load File.expand_path(File.join(__dir__, '../../lib/puppet/gettext/stubs.rb'))
  end

  before :each do
    Puppet[:disable_i18n] = false
  end
end
