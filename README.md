### Docker Amazon Linux (2014.09) with pe-puppet 3.7.1

Amazon Linux 2014.09 + tools + Puppet Enterprise 3.7.1

Includes a basic layout of a new puppet site with some best practices like librarian-puppet, hiera, external facts, etc.

#### Getting started

Build your own image (or get it from docker hub), then use the run target while passing in the hostname (H=) and the desired name (NAME=).

    $ make build
    $ make run H=desired-host.domain.com NAME=test

Modify your Puppetfile to add more modules, and your site.pp is in manifests/. By default it imports manifests/bootstrap and does some node name based classification.

Place any custom facts into facts.d/ directory and put your data into hiera/. {hiera,facts.d}/{local,secret}.{txt,yaml} are ignored from git, so they make a good place to put your local site-specific and secret information.


#### Amit Bakshi 1/6/2015
