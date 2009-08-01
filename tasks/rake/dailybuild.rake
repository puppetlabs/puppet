desc "Create a Puppet daily build"
task :daily => :changelog do
  version = "puppet" + "-" + Time.now.localtime.strftime("%Y%m%d")
  sh "git archive --format=tar --prefix=#{version}/ HEAD^{tree} >#{version}.tar"
  sh "pax -waf #{version}.tar -s ':^:#{version}/:' ChangeLog"
  sh "rm ChangeLog"
  sh "gzip -f -9 #{version}.tar"
end

