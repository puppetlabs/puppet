require 'spec_helper'

require 'puppet/transaction/report'
require 'puppet/indirector/report/yaml'

describe Puppet::Transaction::Report::Yaml do
  describe '#save' do
    subject(:indirection) { described_class.indirection }

    let(:request) { described_class.new }
    let(:certname) { 'ziggy' }
    let(:report) do
      report = Puppet::Transaction::Report.new
      report.host = certname
      report
    end
    let(:file) { request.path(:me) }

    before do
      indirection.terminus_class = :yaml
    end

    it 'is saves a report' do
      indirection.save(report)
    end

    it 'saves the instance of the report as YAML to disk' do
      indirection.save(report)
      content = Puppet::Util::Yaml.safe_load_file(
        Puppet[:lastrunreport], [Puppet::Transaction::Report]
      )
      expect(content.host).to eq(certname)
    end

    it 'allows mode overwrite' do
      Puppet.settings.setting(:lastrunreport).mode = '0644'
      indirection.save(report)

      if Puppet::Util::Platform.windows?
        require 'puppet/util/windows/security'
        mode = Puppet::Util::Windows::Security.get_mode(file)
      else
        mode = Puppet::FileSystem.stat(file).mode
      end

      expect(mode & 07777).to eq(0644)
    end

    context 'when mode is invalid' do
      before do
        Puppet.settings.setting(:lastrunreport).mode = '9999'
      end

      after do
        Puppet.settings.setting(:lastrunreport).mode = '0644'
      end

      it 'raises Puppet::DevError ' do
        expect{
          indirection.save(report)
        }.to raise_error(Puppet::DevError, "replace_file mode: 9999 is invalid")
      end
    end

    context 'when repport is invalid' do
      it 'logs error' do
        expect(Puppet).to receive(:send_log).with(:err, /Could not save yaml ziggy: can't dump anonymous class/)

        report.configuration_version = Class.new
        indirection.save(report)
      end
    end

    context 'when report cannot be saved' do
      it 'raises Errno::EISDIR' do
        FileUtils.mkdir_p(file)
        expect {
          indirection.save(report)
         }.to raise_error(Errno::EISDIR, /last_run_report.yaml/)
      end
    end
  end
end
