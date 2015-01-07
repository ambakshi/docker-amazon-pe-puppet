FROM ambakshi/amazon-linux
MAINTAINER Amit Bakshi <ambakshi@gmail.com>
ENV PE_VERSION 3.7.1
VOLUME /data

RUN rpmkeys --import http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs
RUN mkdir -p /data && curl -fsSL https://s3.amazonaws.com/pe-builds/released/${PE_VERSION}/puppet-enterprise-${PE_VERSION}-el-6-x86_64.tar.gz | tar zxf - -C /data && \
        echo -e '[pe-repo]\nname=pe-repo\nbaseurl=file:///data/puppet-enterprise-'${PE_VERSION}'-el-6-x86_64/packages/el-6-x86_64/\npriority=10\nenabled=1\n' > /etc/yum.repos.d/pe.repo && \
        yum install -y --disablerepo='*' --enablerepo='pe-repo' pe-puppet
RUN mkdir -p /etc/facter/facts.d /etc/puppetlabs/facter && ln -sfn /etc/facter/facts.d /etc/puppetlabs/facter/

WORKDIR /etc/puppetlabs/puppet
CMD ["/usr/local/bin/puppet","apply","--test","--verbose","/etc/puppetlabs/puppet/manifests/site.pp"]
