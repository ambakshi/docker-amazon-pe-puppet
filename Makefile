.PHONY: all run image clean restart run rm rmi

TOP:=$(shell pwd -P)
USER:=$(shell id -un)
AWS_DEFAULT_REGION:=$(shell curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $$4}')

REPO=ambakshi
TAG=2014.09
BASE=amazon-linux
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

all: vendor modules

build: .build/Dockerfile
vendor: .build/vendor
modules: .build/modules
.build:
	@mkdir -p $@

.build/vendor: Gemfile
	bundle install --path $(@F) --binstubs bin
	@mkdir -p $(@D) && touch $@

.build/modules: .build/vendor Puppetfile
	bin/librarian-puppet install
	@mkdir -p $(@D) && touch $@


.build/Dockerfile.$(BASE): Dockerfile.$(BASE) .build/modules
	docker build -t $(REPO)/$(BASE) - < $<
	docker rmi $(REPO)/$(BASE):$(TAG)
	docker tag $(REPO)/$(BASE):latest $(REPO)/$(BASE):$(TAG)
	docker push $(REPO)/$(BASE)
	@mkdir -p $(@D) && touch $@


.build/Dockerfile: .build/Dockerfile.$(BASE)
	docker build -t $(REPO)/$(IMAGE) .
	@mkdir -p $(@D) && touch $@

start: .build/Dockerfile
	@set +e; docker start $(NAME) && docker attach $(NAME); \
     R=$$?; test $$R -eq 0 -o $$R -eq 2
	docker rm -f $(NAME)

exec: .build/Dockerfile
	@docker exec -ti $(NAME) /bin/bash -l || \
      $(DOCKER_RUN) --rm --entrypoint /bin/bash $(REPO)/$(IMAGE) -l

run: .build/Dockerfile
	@set +e; docker rm -f $(NAME) 2>/dev/null ; \
       $(DOCKER_RUN) --name $(NAME) $(REPO)/$(IMAGE) ; \
     R=$$?; test $$R -eq 0 -o $$R -eq 2
	docker rm -f $(NAME)

clean: rm
	rm -rf vendor bin modules .build

rm:
	docker rm -f $(NAME) || true
	docker rmi $(IMAGE)

rmi:
	docker rmi `docker images --filter=dangling=true -q`
