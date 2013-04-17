require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Tar::Gnu do
  let(:sourcefile) { '/the/module.tar.gz' }
  let(:destdir)    { '/the/dest/dir' }
  let(:sourcedir)  { '/the/src/dir' }
  let(:destfile)   { '/the/dest/file.tar.gz' }

  it "unpacks a tar file" do
    Puppet::Util::Execution.expects(:execute).with("tar xzf #{sourcefile} -C #{destdir}")
    subject.unpack(sourcefile, destdir)
  end

  it "packs a tar file" do
    Puppet::Util::Execution.expects(:execute).with("tar cf - #{sourcedir} | gzip -c > #{destfile}")
    subject.pack(sourcedir, destfile)
  end
end
