test_name "#15560: Manage home directories"

confine :to, :platform => 'windows'

username = "pl#{rand(99999).to_i}"

manifest_present = <<-EOM
user { '#{username}':
  ensure     => present,
  managehome => true,
  password   => 'Password123!!',
}
EOM

manifest_absent = <<-EOM
user { '#{username}':
  ensure     => present,
  managehome => true,
}
EOM

agents.each do |host|
  on(host, puppet_apply, :stdin => manifest_present)

  deleteable_profile = true

  version = on(host, facter('operatingsystemrelease')).stdout.chomp
  if version =~ /^5\.[012]/
    homedir = "C:/Documents and Settings/#{username}"
    deleteable_profile = false
  else
    homedir = "C:/Users/#{username}"
  end

  on(host, "test -d '#{homedir}'")

  on(host, puppet_apply, :stdin => manifest_absent)

  if deleteable_profile
    on(host, "test ! -d '#{homedir}'")
  end
end
