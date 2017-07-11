require_relative '../integration_helper'

describe Apply do
  context 'notify' do
    let(:notify) {
      <<-MANIFEST
          notify{'it werks!':}
      MANIFEST
    }
    it 'does its thang' do
      expect(described_class.new.manifest(notify)).to output('it werksasf')
    end
  end
end
