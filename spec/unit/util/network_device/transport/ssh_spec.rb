require 'spec_helper'

require 'puppet/util/network_device/transport/ssh'

describe Puppet::Util::NetworkDevice::Transport::Ssh, :if => Puppet.features.ssh? do
  before(:each) do
    @transport = Puppet::Util::NetworkDevice::Transport::Ssh.new()
  end

  it "should handle login through the transport" do
    expect(@transport).to be_handles_login
  end

  it "should connect to the given host and port" do
    ssh_connection = double(
      "ssh connection",
      open_channel: nil,
      loop: nil,
    )
    expect(Net::SSH).to receive(:start).with("localhost", anything, hash_including(port: 22)).and_return(ssh_connection)
    @transport.host = "localhost"
    @transport.port = 22

    @transport.connect
  end

  it "should connect using the given username and password" do
    ssh_connection = double(
      "ssh connection",
      open_channel: nil,
      loop: nil,
    )
    expect(Net::SSH).to receive(:start).with(anything, "user", hash_including(password: "pass")).and_return(ssh_connection)
    @transport.user = "user"
    @transport.password = "pass"

    @transport.connect
  end

  it "should raise a Puppet::Error when encountering an authentication failure" do
    expect(Net::SSH).to receive(:start).and_raise(Net::SSH::AuthenticationFailed)
    @transport.host = "localhost"
    @transport.user = "user"

    expect { @transport.connect }.to raise_error Puppet::Error
  end

  describe "when connected" do
    before(:each) do
      @ssh = double(
        'ssh',
        loop: nil,
      )
      @channel = double(
        'channel',
        request_pty: nil,
        send_channel_request: nil,
        on_close: nil,
        on_extended_data: nil,
        on_data: nil,
      )
      allow(Net::SSH).to receive(:start).and_return(@ssh)
      allow(@ssh).to receive(:open_channel).and_yield(@channel)
      allow(@transport).to receive(:expect)
    end

    it "should open a channel" do
      expect(@ssh).to receive(:open_channel)

      @transport.connect
    end

    it "should request a pty" do
      expect(@channel).to receive(:request_pty)

      @transport.connect
    end

    it "should create a shell channel" do
      expect(@channel).to receive(:send_channel_request).with("shell")
      @transport.connect
    end

    it "should raise an error if shell channel creation fails" do
      expect(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, false)
      expect { @transport.connect }.to raise_error(RuntimeError, /failed to open ssh shell channel/)
    end

    it "should register an on_data and on_extended_data callback" do
      expect(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      expect(@channel).to receive(:on_data)
      expect(@channel).to receive(:on_extended_data)
      @transport.connect
    end

    it "should accumulate data to the buffer on data" do
      expect(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      expect(@channel).to receive(:on_data).and_yield(@channel, "data")

      @transport.connect
      expect(@transport.buf).to eq("data")
    end

    it "should accumulate data to the buffer on extended data" do
      expect(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      expect(@channel).to receive(:on_extended_data).and_yield(@channel, 1, "data")

      @transport.connect
      expect(@transport.buf).to eq("data")
    end

    it "should mark eof on close" do
      expect(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      expect(@channel).to receive(:on_close).and_yield()

      @transport.connect
      expect(@transport).to be_eof
    end

    it "should expect output to conform to the default prompt" do
      expect(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      expect(@transport).to receive(:default_prompt).and_return("prompt")
      expect(@transport).to receive(:expect).with("prompt")
      @transport.connect
    end

    it "should start the ssh loop" do
      expect(@ssh).to receive(:loop)
      @transport.connect
    end
  end

  describe "when closing" do
    before(:each) do
      @ssh = double('ssh', close: nil)
      @channel = double(
        'channel',
        request_pty: nil,
        on_data: nil,
        on_extended_data: nil,
        on_close: nil,
        close: nil,
      )
      allow(Net::SSH).to receive(:start).and_return(@ssh)
      allow(@ssh).to receive(:open_channel).and_yield(@channel)
      allow(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      allow(@transport).to receive(:expect)
      @transport.connect
    end

    it "should close the channel" do
      expect(@channel).to receive(:close)
      @transport.close
    end

    it "should close the ssh session" do
      expect(@ssh).to receive(:close)
      @transport.close
    end
  end

  describe "when sending commands" do
    before(:each) do
      @ssh = double('ssh')
      @channel = double(
        'channel',
        request_pty: nil,
        on_data: nil,
        on_extended_data: nil,
        on_close: nil,
        send_data: nil,
      )
      allow(Net::SSH).to receive(:start).and_return(@ssh)
      allow(@ssh).to receive(:open_channel).and_yield(@channel)
      allow(@channel).to receive(:send_channel_request).with("shell").and_yield(@channel, true)
      allow(@transport).to receive(:expect)
      @transport.connect
    end

    it "should send data to the ssh channel" do
      expect(@channel).to receive(:send_data).with("data\n")
      @transport.command("data")
    end

    it "should expect the default prompt afterward" do
      expect(@transport).to receive(:default_prompt).and_return("prompt")
      expect(@transport).to receive(:expect).with("prompt")
      @transport.command("data")
    end

    it "should expect the given prompt" do
      expect(@transport).to receive(:expect).with("myprompt")
      @transport.command("data", :prompt => "myprompt")
    end

    it "should yield the buffer output to given block" do
      expect(@transport).to receive(:expect).and_yield("output")
      @transport.command("data") do |out|
        expect(out).to eq("output")
      end
    end

    it "should return buffer output" do
      expect(@transport).to receive(:expect).and_return("output")
      expect(@transport.command("data")).to eq("output")
    end
  end

  describe "when expecting output" do
    before(:each) do
      @connection = double('connection')
      @socket = double(
        'socket',
        :closed? => nil,
      )
      transport = double('transport', :socket => @socket)
      @ssh = double('ssh', :transport => transport)
      @channel = double('channel', :connection => @connection)
      @transport.ssh = @ssh
      @transport.channel = @channel
    end

    it "should process the ssh event loop" do
      allow(IO).to receive(:select)
      @transport.buf = "output"
      expect(@transport).to receive(:process_ssh)
      @transport.expect(/output/)
    end

    it "should return the output" do
      allow(IO).to receive(:select)
      @transport.buf = "output"
      allow(@transport).to receive(:process_ssh)
      expect(@transport.expect(/output/)).to eq("output")
    end

    it "should return the output" do
      allow(IO).to receive(:select)
      @transport.buf = "output"
      allow(@transport).to receive(:process_ssh)
      expect(@transport.expect(/output/)).to eq("output")
    end

    describe "when processing the ssh loop" do
      it "should advance one tick in the ssh event loop and exit on eof" do
        @transport.buf = ''
        expect(@connection).to receive(:process).and_raise(EOFError)
        @transport.process_ssh
      end
    end
  end
end
