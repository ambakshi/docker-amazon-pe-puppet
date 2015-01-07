FROM vettl/amazon-linux

MAINTAINER Amit Bakshi <ambakshi@gmail.com>
ENV PE_VERSION 3.7.1

RUN yum update -y -x kernel -x kernel-devel
RUN yum install -y cronie-anacron rsyslog openssh-server openssh tar wget curl man
RUN yum install -y git diffstat make m4 vim-enhanced ruby-devel rubygems gcc
RUN rpmkeys --import http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs
RUN gem install --no-ri --no-rdoc bundler
RUN curl -fsSL https://s3.amazonaws.com/pe-builds/released/${PE_VERSION}/puppet-enterprise-${PE_VERSION}-el-6-x86_64.tar.gz | tar zxf - -C /root
RUN echo -e '[pe-repo]\nname=pe-repo\nbaseurl=file:///root/puppet-enterprise-'${PE_VERSION}'-el-6-x86_64/packages/el-6-x86_64/\npriority=10\nenabled=1\n' > /etc/yum.repos.d/pe.repo
RUN yum install -y pe-puppet
RUN mkdir -p /etc/facter/facts.d /etc/puppetlabs/facter && ln -sfn /etc/facter/facts.d /etc/puppetlabs/facter/

WORKDIR /etc/puppetlabs/puppet
CMD ["/usr/local/bin/puppet","apply","--test","--verbose","/etc/puppetlabs/puppet/manifests/site.pp"]
