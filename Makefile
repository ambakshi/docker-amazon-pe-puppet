.PHONY: all run image clean push restart run rm

TOP:=$(shell pwd -P)
USER:=$(shell id -un)
AWS_DEFAULT_REGION:=$(shell curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $$4}')

IMAGE=amazon-pe-puppet
H=puppet-slave.example.com
NAME=puppet-slave
CONFDIR=/etc/puppetlabs/puppet

DOCKER_ENV=-e FACTER_region=$(AWS_DEFAULT_REGION) -e AWS_DEFAULT_REGION -e HOME=/root
DOCKER_VOL=\
      -v $(TOP)/manifests:$(CONFDIR)/manifests:ro \
      -v $(TOP)/modules:/opt/puppet/share/puppet/modules:ro \
      -v $(TOP)/site_modules:$(CONFDIR)/modules:ro \
      -v $(TOP)/hiera:/var/lib/hiera:ro \
      -v $(TOP)/facts.d:/etc/facter/facts.d:ro \
      -v /bin/true:/sbin/service:ro -v /bin/true:/sbin/initctl:ro
DOCKER_RUN=docker run -ti -w $(CONFDIR) $(DOCKER_ENV) $(DOCKER_VOL) -h $(H)

export AWS_DEFAULT_REGION

all: vendor modules build

vendor: Gemfile
	bundle install --path $(TOP)/$@ --binstubs $(TOP)/bin

modules: vendor Puppetfile
	$(TOP)/bin/librarian-puppet install

build: .build

.build: Dockerfile
	docker build -t $(IMAGE) .
	@touch $@

push: .build
	docker tag $(IMAGE) $(USER)/$(IMAGE):latest
	docker push $(USER)/$(IMAGE):latest

start: .build
	@set +e; docker start $(NAME) && docker attach $(NAME); \
     R=$$?; test $$R -eq 0 -o $$R -eq 2
	docker rm -f $(NAME)

exec: .build
	@docker exec -ti $(NAME) /bin/bash -l || \
      $(DOCKER_RUN) --rm --entrypoint /bin/bash $(IMAGE) -l

run: .build
	set +e; docker rm -f $(NAME) 2>/dev/null ; \
       $(DOCKER_RUN) --name $(NAME) $(IMAGE) ; \
     R=$$?; test $$R -eq 0 -o $$R -eq 2
	docker rm -f $(NAME)

clean: rm
	rm -rf vendor bin modules .build

rm:
	docker rm -f $(NAME) || true
