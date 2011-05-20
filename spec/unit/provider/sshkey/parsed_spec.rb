#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:sshkey).provider(:parsed)

describe provider_class do
  before do
    @sshkey_class = Puppet::Type.type(:sshkey)
    @provider_class = @sshkey_class.provider(:parsed)
    @key = 'AAAAB3NzaC1yc2EAAAABIwAAAQEAzwHhxXvIrtfIwrudFqc8yQcIfMudrgpnuh1F3AV6d2BrLgu/yQE7W5UyJMUjfj427sQudRwKW45O0Jsnr33F4mUw+GIMlAAmp9g24/OcrTiB8ZUKIjoPy/cO4coxGi8/NECtRzpD/ZUPFh6OEpyOwJPMb7/EC2Az6Otw4StHdXUYw22zHazBcPFnv6zCgPx1hA7QlQDWTu4YcL0WmTYQCtMUb3FUqrcFtzGDD0ytosgwSd+JyN5vj5UwIABjnNOHPZ62EY1OFixnfqX/+dUwrFSs5tPgBF/KkC6R7tmbUfnBON6RrGEmu+ajOTOLy23qUZB4CQ53V7nyAWhzqSK+hw=='
  end

  it "should parse the name from the first field" do
    @provider_class.parse_line('test ssh-rsa '+@key)[:name].should == "test"
  end

  it "should parse the first component of the first field as the name" do
    @provider_class.parse_line('test,alias ssh-rsa '+@key)[:name].should == "test"
  end

  it "should parse host_aliases from the remaining components of the first field" do
    @provider_class.parse_line('test,alias ssh-rsa '+@key)[:host_aliases].should == ["alias"]
  end

  it "should parse multiple host_aliases" do
    @provider_class.parse_line('test,alias1,alias2,alias3 ssh-rsa '+@key)[:host_aliases].should == ["alias1","alias2","alias3"]
  end

  it "should not drop an empty host_alias" do
    @provider_class.parse_line('test,alias, ssh-rsa '+@key)[:host_aliases].should == ["alias",""]
  end

  it "should recognise when there are no host aliases" do
    @provider_class.parse_line('test ssh-rsa '+@key)[:host_aliases].should == []
  end

end
