require 'spec_helper'

if Puppet.features.telnet?
  require 'puppet/util/network_device/transport/telnet'

  describe Puppet::Util::NetworkDevice::Transport::Telnet do

    before(:each) do
      tcp = double(
        'tcp',
        :sync= => nil,
        :binmode => nil,
      )
      allow(TCPSocket).to receive(:open).and_return(tcp)
      @transport = Puppet::Util::NetworkDevice::Transport::Telnet.new()
    end

    it "should not handle login through the transport" do
      expect(@transport).not_to be_handles_login
    end

    it "should not open any files" do
      expect(File).not_to receive(:open)
      @transport.host = "localhost"
      @transport.port = 23

      @transport.connect
    end

    it "should connect to the given host and port" do
      expect(Net::Telnet).to receive(:new).with(hash_including("Host" => "localhost", "Port" => 23)).and_return(double("telnet connection"))
      @transport.host = "localhost"
      @transport.port = 23

      @transport.connect
    end

    it "should connect and specify the default prompt" do
      @transport.default_prompt = "prompt"
      expect(Net::Telnet).to receive(:new).with(hash_including("Prompt" => "prompt")).and_return(double("telnet connection"))
      @transport.host = "localhost"
      @transport.port = 23

      @transport.connect
    end

    describe "when connected" do
      before(:each) do
        @telnet = double('telnet')
        allow(Net::Telnet).to receive(:new).and_return(@telnet)
        @transport.connect
      end

      it "should send line to the telnet session" do
        expect(@telnet).to receive(:puts).with("line")
        @transport.send("line")
      end

      describe "when expecting output" do
        it "should waitfor output on the telnet session" do
          expect(@telnet).to receive(:waitfor).with(/regex/)
          @transport.expect(/regex/)
        end

        it "should return telnet session output" do
          expect(@telnet).to receive(:waitfor).and_return("output")
          expect(@transport.expect(/regex/)).to eq("output")
        end

        it "should yield telnet session output to the given block" do
          expect(@telnet).to receive(:waitfor).and_yield("output")
          @transport.expect(/regex/) { |out| expect(out).to eq("output") }
        end
      end
    end

    describe "when closing" do
      before(:each) do
        @telnet = double('telnet')
        allow(Net::Telnet).to receive(:new).and_return(@telnet)
        @transport.connect
      end

      it "should close the telnet session" do
        expect(@telnet).to receive(:close)
        @transport.close
      end
    end
  end
end
