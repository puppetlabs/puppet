require 'spec_helper'

[:seluser, :selrole, :seltype, :selrange].each do |param|
  property = Puppet::Type.type(:file).attrclass(param)
  describe property do
    include PuppetSpec::Files

    before do
      @path = make_absolute("/my/file")
      @resource = Puppet::Type.type(:file).new :path => @path
      @sel = property.new :resource => @resource
    end

    it "retrieve on #{param} should return :absent if the file isn't statable" do
      expect(@resource).to receive(:stat).and_return(nil)
      expect(@sel.retrieve).to eq(:absent)
    end

    it "should retrieve nil for #{param} if there is no SELinux support" do
      stat = double('stat', :ftype => "foo")
      expect(@resource).to receive(:stat).and_return(stat)
      expect(@sel).to receive(:get_selinux_current_context).with(@path).and_return(nil)
      expect(@sel.retrieve).to be_nil
    end

    it "should retrieve #{param} if a SELinux context is found with a range" do
      stat = double('stat', :ftype => "foo")
      expect(@resource).to receive(:stat).and_return(stat)
      expect(@sel).to receive(:get_selinux_current_context).with(@path).and_return("user_u:role_r:type_t:s0")
      expectedresult = case param
        when :seluser; "user_u"
        when :selrole; "role_r"
        when :seltype; "type_t"
        when :selrange; "s0"
      end
      expect(@sel.retrieve).to eq(expectedresult)
    end

    it "should retrieve #{param} if a SELinux context is found without a range" do
      stat = double('stat', :ftype => "foo")
      expect(@resource).to receive(:stat).and_return(stat)
      expect(@sel).to receive(:get_selinux_current_context).with(@path).and_return("user_u:role_r:type_t")
      expectedresult = case param
        when :seluser; "user_u"
        when :selrole; "role_r"
        when :seltype; "type_t"
        when :selrange; nil
      end
      expect(@sel.retrieve).to eq(expectedresult)
    end

    it "should handle no default gracefully" do
      expect(@sel).to receive(:get_selinux_default_context).with(@path, @resource[:ensure].to_s).and_return(nil)
      expect(@sel.default).to be_nil
    end

    it "should be able to detect matchpathcon defaults" do
      allow(@sel).to receive(:debug)
      expect(@sel).to receive(:get_selinux_default_context).with(@path, @resource[:ensure].to_s).and_return("user_u:role_r:type_t:s0")
      expectedresult = case param
        when :seluser; "user_u"
        when :selrole; "role_r"
        when :seltype; "type_t"
        when :selrange; "s0"
      end
      expect(@sel.default).to eq(expectedresult)
    end

    it "should return nil for defaults if selinux_ignore_defaults is true" do
      @resource[:selinux_ignore_defaults] = :true
      expect(@sel.default).to be_nil
    end

    it "should be able to set a new context" do
      @sel.should = %w{newone}
      expect(@sel).to receive(:set_selinux_context).with(@path, ["newone"], param)
      @sel.sync
    end

    it "should do nothing for safe_insync? if no SELinux support" do
      @sel.should = %{newcontext}
      expect(@sel).to receive(:selinux_support?).and_return(false)
      expect(@sel.safe_insync?("oldcontext")).to eq(true)
    end
  end
end
