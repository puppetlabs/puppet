require 'puppet/gettext/text_domain_service'
require 'spec_helper'

describe Puppet::TextDomainService do
  let(:env) { Puppet::Node::Environment.create(:production, []) }

  context 'when i18n is enabled' do
    before :each do
      Puppet[:disable_i18n] = false
    end

    subject { described_class.create }

    it 'loads module translations' do
      expect(Puppet::GettextConfig).to receive(:reset_text_domain).with(:production)
      expect(Puppet::ModuleTranslations).to receive(:load_from_modulepath).with([])

      subject.created(env)
    end

    it 'deletes module translations' do
      expect(Puppet::GettextConfig).to receive(:delete_text_domain).with(:production)

      subject.evicted(env)
    end
  end

  context 'when i18n is disabled' do
    before :each do
      Puppet[:disable_i18n] = true
    end

    subject { described_class.create }

    it 'does not load module translations' do
      expect(Puppet::GettextConfig).to receive(:reset_text_domain).never
      expect(Puppet::ModuleTranslations).to receive(:load_from_modulepath).never

      subject.created(env)
    end

    it 'does not delete module translations' do
      expect(Puppet::GettextConfig).to receive(:delete_text_domain).never

      subject.evicted(env)
    end
  end
end
