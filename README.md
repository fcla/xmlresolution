XML Resolution Service
======================
Consider a collection of XML documents.  You would like to gather up
all of the schemas necessary to understand those documents for
preservation purposes.  This web service helps you do that, in three
RESTful steps:

  1. Create a collection resource.
  2. POST some XML documents to the collection.
  3. GET the collection, retrieving a tar file of the XML schemas and a manifest of what was done.

The original XML documents are not returned.  It is recommended that
you employ a caching proxy such as squid when used in a production
environment.


Envronment
----------

In your web server you should set up some environment variables:

  * SetEnv DATA_ROOT - where you'll save information about the schemas and document collections.
  * SetEnv RESOLVER_PROXY squid.example.com:3128 - an optional squid caching proxy.
  * SetEnv LOG_FACILITY LOG_LOCAL1 - set a facility code if you use syslog for logging.

Requirements
------------
Known to work with with ruby 1.8.7. The following packages (beyond the
standards)

  * sinatra & rack
  * nokogiri, libxml-ruby & builder
  * rake, rspec, cucumber & ci/reporter for testing.
  * log4r
  * capistrano & railsless-deploy.

Quickstart
----------

  1. Retrieve a copy of the xmlresolution service.
  2. Test the installation:
	`% rake spec`
  3. Run from rackup, specifying your environment:
	`% RESOLVER_PROXY=squid.example.com:3128  rackup config.ru`
     or run under a web server.  I'm using passenger phusion under apache:

`
	<VirtualHost>
	  ServerName xmlresolution.example.com
	  DocumentRoot "/.../xmlresolution/public"
	  SetEnv DATA_ROOT /var/resolutions
	  SetEnv RESOLVER_PROXY squid.example.com:3128
	  SetEnv LOG_FACILITY LOG_LOCAL2
	  <Directory "/.../xmlresolution/public">
	    Order allow,deny
	    Allow from all
	  </Directory>
	</VirtualHost>`


Directory Structure
-------------------
You can use the supplied Capfile to set up. Adjust
the top few lines in that file to match your installation.

 * config.ru & app.rb - the Sinatra setup
 * public/            - programming docs will land in public/internals here via % rake yard; otherwise empty
 * views/             - instructional erb pages and forms
 * lib/app/           - root of the sinatra stuff - helpers and routes
 * lib/xmlresolution/ - root of the xmlresolution libraries
 * spec/              - tests
 * data/              - example DATA_ROOT which must have the directories:
 * data/schemas       - where cached schemas live
 * data/collections   - where collections, and information about submitted documents for a collection, live
 * tmp/               - phusion checks the restart.txt file here.  Rake has a restart target for this, capistrano uses it

Usage
-----
The following assumes you've a running server at xmlresolution.example.com.
There are built-in test forms for exploring the system; see http://xmlresolution.example.com/ for
instructions.  The following models how your RESTful clients should access the service.

 * Create a collection (some versions of curl require you to use an empty document here):

	 `curl --upload-file /dev/null -X PUT http://xmlresolution.example.com/ieids/collection-001`

 * Submit some XML documents to it (note trailing slash):

	`curl -F xmlfile=@myfile.xml http://xmlresolution.example.com/ieids/collection-001/`

	`curl -F xmlfile=@myotherfile.xml http://xmlresolution.example.com/ieids/collection-001/`

 * Get the tarfile of the associated schemas and a manifest

	`curl http://xmlresolution.example.com/ieids/collection-001/`

Documentation
-------------
See the root of the running service for a web page of instructions on
use and testing; there is a Rake task that will install the
application documentation under public/internals.
