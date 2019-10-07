require 'spec_helper'
require 'puppet/reports'

processor = Puppet::Reports.report(:http)

describe processor do
  subject { Puppet::Transaction::Report.new.extend(processor) }

  describe "when setting up the connection" do
    let(:http) { double("http") }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }

    before :each do
      expect(http).to receive(:post).and_return(httpok)
    end

    it "configures the connection for ssl when using https" do
      Puppet[:reporturl] = 'https://testing:8080/the/path'

      expect(Puppet::Network::HttpPool).to receive(:connection).with(
        'testing', 8080, hash_including(ssl_context: instance_of(Puppet::SSL::SSLContext))
      ).and_return(http)

      subject.process
    end

    it "does not configure the connection for ssl when using http" do
      Puppet[:reporturl] = 'http://testing:8080/the/path'

      expect(Puppet::Network::HttpPool).to receive(:connection).with(
        'testing', 8080, use_ssl: false, ssl_context: nil
      ).and_return(http)

      subject.process
    end
  end

  describe "when making a request" do
    let(:connection) { double("connection") }
    let(:httpok) { Net::HTTPOK.new('1.1', 200, '') }
    let(:options) { {:metric_id => [:puppet, :report, :http]} }

    before :each do
      expect(Puppet::Network::HttpPool).to receive(:connection).and_return(connection)
    end

    it "should use the path specified by the 'reporturl' setting" do
      report_path = URI.parse(Puppet[:reporturl]).path
      expect(connection).to receive(:post).with(report_path, anything, anything, options).and_return(httpok)

      subject.process
    end

    it "should use the username and password specified by the 'reporturl' setting" do
      Puppet[:reporturl] = "https://user:pass@myhost.mydomain:1234/report/upload"

      expect(connection).to receive(:post).with(anything, anything, anything,
                                                {:metric_id => [:puppet, :report, :http],
                                                 :basic_auth => {
                                                   :user => 'user',
                                                   :password => 'pass'
                                                 }}).and_return(httpok)

      subject.process
    end

    it "should give the body as the report as YAML" do
      expect(connection).to receive(:post).with(anything, subject.to_yaml, anything, options).and_return(httpok)

      subject.process
    end

    it "should set content-type to 'application/x-yaml'" do
      expect(connection).to receive(:post).with(anything, anything, hash_including("Content-Type" => "application/x-yaml"), options).and_return(httpok)

      subject.process
    end

    Net::HTTPResponse::CODE_TO_OBJ.each do |code, klass|
      if code.to_i >= 200 and code.to_i < 300
        it "should succeed on http code #{code}" do
          response = klass.new('1.1', code, '')
          expect(connection).to receive(:post).and_return(response)

          expect(Puppet).not_to receive(:err)
          subject.process
        end
      end

      if code.to_i >= 300 && ![301, 302, 307].include?(code.to_i)
        it "should log error on http code #{code}" do
          response = klass.new('1.1', code, '')
          expect(connection).to receive(:post).and_return(response)

          expect(Puppet).to receive(:err)
          subject.process
        end
      end
    end
  end
end
