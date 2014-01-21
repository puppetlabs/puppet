class apache::php{
  package{'libapache2-mod-php5':
    making_sure => present,
  }
}
