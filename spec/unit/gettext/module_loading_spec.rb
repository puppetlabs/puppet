require 'spec_helper'
require 'puppet_spec/modules'
require 'puppet_spec/files'

require 'puppet/gettext/module_translations'

describe Puppet::ModuleTranslations do
  include PuppetSpec::Files

  describe "loading translations from the module path" do
    let(:modpath) { tmpdir('modpath') }

    let(:module_a) { PuppetSpec::Modules.create(
      "mod_a",
      modpath,
      :metadata => {
        :author => 'foo'
      },
      :environment => mock("environment")) }

      it 'should attempt to load translations for each module given' do
        Puppet::GettextConfig.expects(:load_translations).with("foo-mod_a", File.join(modpath, "mod_a", "locales"), :po).returns(true)

        Puppet::ModuleTranslations.from_modulepath([module_a])
      end
  end

  describe "loading translations from $vardir" do
    let(:vardir) {
      dir_containing("vardir",
        { "locales" => { "ja" => { "foo-mod_a.po" => "" } } })
    }

    it "should attempt to load translations for the current locale" do
      Puppet::GettextConfig.expects(:current_locale).returns("ja")
      Puppet::GettextConfig.expects(:load_translations).with("foo-mod_a", File.join(vardir, "locales"), :po).returns(true)

      Puppet::ModuleTranslations.from_vardir(vardir)
    end
  end
end
