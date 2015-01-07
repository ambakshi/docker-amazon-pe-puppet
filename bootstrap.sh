#!/bin/bash

cd /root
yum clean all
yum update -y
yum install -y awscli man which tar gzip ruby ruby-devel rubygems python python-devel hg ctags-etags sudo bash-completion curl gcc gcc-c++ make openssh openssh-server openssh-clients git epel-release vim-enhanced bzip2 wget python-pip
yum install -y rpmdevtools rpm-build rpm-libs


# curl -fsSL https://gist.githubusercontent.com/ambakshi/51c994271a216016edef/raw/bootstrap.sh | /bin/bash -e || true
curl -fsSL bit.ly/devbootstrap | bash -e || true

## Install fpm so we can make an empty gtk2 package
if ! rpm -qa | grep '^gtk2'; then
	mkdir -p /tmp/fpm/etc
	touch /tmp/fpm/etc/gtk2-fake.conf
	gem install --no-rdoc --no-ri fpm
	rm -f gtk2*.rpm
	fpm -s dir -t rpm -n gtk2 -v 2.0 -C /tmp/fpm etc/
	rpm -Uvh gtk2*
	rm -rf /tmp/fpm
fi

echo "PS1='\[\e[31m\]\h:\w#\[\e[m\] '" >> ~/.bashrc

cd /root

export AWS_DEFAULT_REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}'`

for pkg in puppetlabs-inifile maestrodev-wget \
	   saz-resolv_conf puppetlabs/postgresql \
	   puppetlabs-vcsrepo; do
	mkdir -p /root/modules
	puppet module install -i /root/modules $pkg
done

S3="ct-shared-bucket"
mkdir -p /etc/facter/facts.d
echo "s3_bucket=$S3" > /etc/facter/facts.d/s3_bucket.txt

if [ -e /etc/puppetlabs ]; then
	mkdir -p /etc/puppetlabs/facter
	ln -sfn /etc/facter/facts.d /etc/puppetlabs/facter
fi

aws s3 cp s3://ct-shared-bucket/bootstrap/pe-master/bootstrap.pp modules/bootstrap/
set +e
DOMAIN=atvict.net
export HOSTNAME=puppet
hostname $HOSTNAME
export FACTER_domain=$DOMAIN
export FACTER_hostname=$HOSTNAME
export FACTER_fqdn=${HOSTNAME}.${DOMAIN}
puppet apply --test --certname ${FACTER_fqdn} --modulepath $PWD/modules $PWD/modules/bootstrap/bootstrap.pp
rc=$?
if [ $rc -eq 0 ] || [ $rc -eq 2 ]; then
	exit 0
fi
exit $rc

### REPLACED BY PUPPET ##########

#echo '. /usr/share/git-core/contrib/completion/git-prompt.sh' | tee -a ~/.bashrc
#echo "PS1='[\[\033[32m\]\u@\h\[\033[00m\] \[\033[36m\]\W\[\033[31m\]\$(__git_ps1)\[\033[00m\]] \$ '" | tee -a ~/.bashrc

IPV4=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain
${IPV4} ${HOSTNAME}.${DOMAIN} ${HOSTNAME}.localdomain ${HOSTNAME}
${IPV4} pe-master.${DOMAIN} pe-master.localdomain pe-master
EOF
sed -i '/HOSTNAME=/d' /etc/sysconfig/network
echo "HOSTNAME=$HOSTNAME" >> /etc/sysconfig/network
IFS=$'\n' NS=($(grep nameserver /etc/resolv.conf))
cp -f /etc/resolv.conf /etc/resolv.conf.`date +%s`
cat > /etc/resolv.conf.$$ <<EOF
domain ${DOMAIN}
search ${DOMAIN} ${AWS_DEFAULT_REGION}.compute.internal
${NS[$@]}
EOF

mv /etc/resolv.conf.$$ /etc/resolv.conf

if ! which pip; then
   easy_install -U pip
   hash -r
fi
if ! which aws; then
   pip install -U awscli
fi

ANSWERS=pe-master-answer-file.txt
PE=puppet-enterprise-3.7.1-el-6-x86_64

aws s3 cp s3://ct-shared-bucket/bootstrap/pe-master/${ANSWERS} /root/${ANSWERS}
chmod 0600 /root/${ANSWERS}

curl -fsSL https://s3.amazonaws.com/pe-builds/released/3.7.1/${PE}.tar.gz | tar zxf -
cd /root/${PE}
./puppet-enterprise-installer -a /root/${ANSWERS} -l /var/log/puppet-enterprise-installer.log
