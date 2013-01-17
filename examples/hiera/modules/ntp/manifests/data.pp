# this class will be loaded using hiera's 'puppet' backend
class ntp::data {
  $ntpservers = ['1.pool.ntp.org', '2.pool.ntp.org']
}
