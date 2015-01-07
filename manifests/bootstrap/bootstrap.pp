include wget

Exec {
  path => '/bin:/usr/bin:/sbin:/usr/sbin',
}

Package {
  allow_virtual => true,
}

if "${::s3_bucket}" == "" {
  file { '/etc/puppetlabs/facter':
    ensure => 'directory',
  } ->
  file { '/etc/puppetlabs/facter/facts.d':
    ensure => 'link',
    target => '/etc/facter/facts.d',
  }
  fail("need to rerun puppet")
}

class basic {
  exec { 'set hostname':
    command => "hostname ${::hostname}",
    unless  => "test ${::hostname} = `hostname -s`",
  }

  ini_setting {'hostname':
    ensure => present,
    path => '/etc/sysconfig/network',
    section => '',
    key_val_separator => '=',
    setting => 'HOSTNAME',
    value => "${::hostname}",
  }

  host { 'local':
    name => "${::fqdn}",
    ensure => present,
    host_aliases => ["${::hostname}.localdomain","${::hostname}","pe-master.${::domain}","pe-master.localdomain","pe-master"],
    comment => "by Puppet for ${::hostname}",
    ip => "${::ipaddress}",
  }

  class {'resolv_conf':
    searchpath => ["${::domain}","us-west-2.compute.internal"],
    nameservers => ['172.31.0.2'],
  }
}

define s3file (
  $target = $title,
  $bucket = "${::s3_bucket}",
  $key = undef,
  $ensure = 'present',) {

  ensure_packages(['aws-cli'])
  exec {"s3://$bucket/$key -> $target":,
    command => "aws s3 cp s3://$bucket/$key $target",
    creates => "$target",
    require => Package['aws-cli'],
  } ->
  file {"$target":
    ensure => $ensure,
  }
}

node /^puppet.atvict.net$/ {
  $answers = "pe-master-answer-file.txt"
  $pe_version_want = "3.7.1"
  $pe_package = "puppet-enterprise-${pe_version_want}-el-6-x86_64"

  class { 'basic': }
  s3file { "/root/${answers}":
    key => "bootstrap/pe-master/${answers}",
    ensure => 'present'
  }
  wget::fetch { 'puppetlabs package':
    source      => "https://s3.amazonaws.com/pe-builds/released/3.7.1/${pe_package}.tar.gz",
    destination => "/root/${pe_package}.tar.gz",
    timeout     => 0,
    verbose     => false,
  } ->
  exec { "extract package":
    command => "tar zxf ${pe_package}.tar.gz -C /root",
    creates => "/root/${pe_package}",
  } ->
  exec { "install pe":
    command => "/root/${pe_package}/puppet-enterprise-installer -a /root/${answers} -l /root/installer.log && touch /root/installer.done",
    creates => '/root/installer.done',
    require => File["/root/${answers}"],
  }
}

node default {
  class { 'basic': }
}
