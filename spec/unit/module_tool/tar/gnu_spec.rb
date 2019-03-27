require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Tar::Gnu do
  let(:sourcefile) { '/space path/the/module.tar.gz' }
  let(:destdir)    { '/space path/the/dest/dir' }
  let(:sourcedir)  { '/space path/the/src/dir' }
  let(:destfile)   { '/space path/the/dest/file.tar.gz' }

  it "unpacks a tar file" do
    expect(Dir).to receive(:chdir).with(File.expand_path(destdir)).and_yield
    expect(Puppet::Util::Execution).to receive(:execute).with("gzip -dc #{Shellwords.shellescape(File.expand_path(sourcefile))} | tar xof -")
    expect(Puppet::Util::Execution).to receive(:execute).with("find . -type d -exec chmod 755 {} +")
    expect(Puppet::Util::Execution).to receive(:execute).with("find . -type f -exec chmod u+rw,g+r,a-st {} +")
    expect(Puppet::Util::Execution).to receive(:execute).with("chown -R <owner:group> .")
    subject.unpack(sourcefile, destdir, '<owner:group>')
  end

  it "packs a tar file" do
    expect(Puppet::Util::Execution).to receive(:execute).with("tar cf - #{sourcedir} | gzip -c > #{File.basename(destfile)}")
    subject.pack(sourcedir, destfile)
  end
end
