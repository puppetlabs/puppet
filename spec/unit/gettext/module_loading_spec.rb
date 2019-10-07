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
      :environment => double("environment"))
    }

    let(:module_b) { PuppetSpec::Modules.create(
      "mod_b",
      modpath,
      :metadata => {
        :author => 'foo'
      },
      :environment => double("environment"))
    }

    it "should attempt to load translations only for modules that have them" do
      expect(module_a).to receive(:has_translations?).and_return(false)
      expect(module_b).to receive(:has_translations?).and_return(true)
      expect(Puppet::GettextConfig).to receive(:load_translations).with("foo-mod_b", File.join(modpath, "mod_b", "locales"), :po).and_return(true)

      Puppet::ModuleTranslations.load_from_modulepath([module_a, module_b])
    end
  end

  describe "loading translations from $vardir" do
    let(:vardir) {
      dir_containing("vardir",
        { "locales" => { "ja" => { "foo-mod_a.po" => "" } } })
    }

    it "should attempt to load translations for the current locale" do
      expect(Puppet::GettextConfig).to receive(:current_locale).and_return("ja")
      expect(Puppet::GettextConfig).to receive(:load_translations).with("foo-mod_a", File.join(vardir, "locales"), :po).and_return(true)

      Puppet::ModuleTranslations.load_from_vardir(vardir)
    end
  end
end
