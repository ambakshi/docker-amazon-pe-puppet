include stdlib
include wget

Exec {
  path => '/bin:/usr/bin:/sbin:/usr/sbin',
}

Package {
  allow_virtual => true,
}

class basic (
  $packages = ['aws-cli']) {

  ensure_packages($packages)

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
    host_aliases => ["${::hostname}.localdomain","${::hostname}"],
    comment => "by Puppet for ${::hostname}",
    ip => "${::ipaddress}",
  }

  # docker=1 is defined in facts.d/docker.txt
  # we use this to skip certain calls that we
  # can't make inside the container due to security
  if $::docker == undef {
    exec { 'set hostname':
      command => "hostname ${::hostname}",
      unless  => "test ${::hostname} = `hostname -s`",
    }
    class {'resolv_conf':
      searchpath => ["${::domain}","${::region}.compute.internal"],
      nameservers => ['172.31.0.2'],
    }
  }
}

define s3file (
  $target = $title,
  $ensure = present,
  $s3_bucket = hiera('s3_bucket'),
  $key = undef,
) {
  exec {"s3://$s3_bucket/$key -> $target":,
    command => "aws s3 cp s3://$s3_bucket/$key $target",
    creates => "$target",
    require => Package['aws-cli'],
  } ->
  file {"$target":
    ensure => $ensure,
  }
}

node /^puppet-master.*/ {
  $pe_version_want = hiera('pe_version_want')
  $pe_package = "puppet-enterprise-${pe_version_want}-el-6-x86_64"
  $s3_answers_key = hiera('s3_answers_key')
  $answers = "pe-master-answer-file.txt"

  include puppetmaster


  class { 'basic': } ->
  s3file { "/root/$answers":
    key    => $s3_answers_key,
    ensure => present
  } ->
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
