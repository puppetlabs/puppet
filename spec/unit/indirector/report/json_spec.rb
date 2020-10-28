require 'spec_helper'

require 'puppet/transaction/report'
require 'puppet/indirector/report/json'

describe Puppet::Transaction::Report::Json do
  include PuppetSpec::Files
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
      Puppet[:lastrunreport] = File.join(Puppet[:statedir], "last_run_report.json")

      indirection.terminus_class = :json
    end

    it 'saves the instance of the report as JSON to disk' do

      indirection.save(report)
      json = Puppet::FileSystem.read(Puppet[:lastrunreport], :encoding => 'bom|utf-8')
      content = Puppet::Util::Json.load(json)
      expect(content["host"]).to eq(certname)
    end

    it 'allows mode overwrite' do
      Puppet.settings.setting(:lastrunreport).mode = '0644'
      indirection.save(report)

      if Puppet::Util::Platform.windows?
        mode = File.stat(file).mode
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

    context 'when report cannot be saved' do
      it 'raises Error' do
        FileUtils.mkdir_p(file)
        expect {
          indirection.save(report)
         }.to raise_error(Errno::EISDIR, /last_run_report.json/)
      end
    end
  end
end
