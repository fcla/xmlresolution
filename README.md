XML Resolution Service
======================
Consider a collection of XML documents.  You would like to gather up all of the schemas necessary
to understand those documents.  This web service helps you do that, in three RESTful steps:

  1. Create a collection resource.
  2. POST some XML documents to the collection.
  3. GET the collection, retrieving a tar file of the schemas and a manifest.

The original XML documents are not kept nor returned in the tar file.

Envronment
----------

In your web server you should set up some environment variables:

  * SetEnv RACK_ENV development - still in beta
  * SetEnv RESOLVER_PROXY sake.fcla.edu:3128 - an optional squid caching proxy
  * SetEnv LOG_FACILITY LOG_LOCAL2 - optionally a facility code if using syslog for logging

Requirements
------------
Known to work with with ruby 1.8.7. The following packages (beyond the standards)

  * sinatra & rack
  * libxml-ruby & builder
  * rake & rspec & cucumber
  * log4r
  * capistrano & railsless-deploy 

Quickstart
----------

  1. Retrieve a copy of the xmlresolution service.  
  2. Test the installation:  `% rake spec`
  3. Run from rackup, specifying your environment: `% RESOLVER_PROXY=squid.example.com:3128  rackup config.ru` or
run under a web server.  I'm using passenger phusion under apache:
	
`
	<VirtualHost>
	  ServerName xmlresolution.example.com
	  DocumentRoot "/.../xmlresolution/public"
	  SetEnv RACK_ENV development
	  SetEnv RESOLVER_PROXY squid.example.com:3128
	  SetEnv LOG_FACILITY LOG_LOCAL2
	  <Directory "/.../xmlresolution/public">
	    Order allow,deny`
	    Allow from all
	  </Directory>
	</VirtualHost>`
 



Directory Structure
-------------------
You can use the supplied Capfile and config/deploy.rb to set up. Adjust
the top two lines in deploy.rb to match your installation.

 * config.ru & app.rb - the Sinatra setup
 * public/            - rdocs land in here via % rake rdoc
 * views/             - instructional erb pages
 * lib/               - root of xmlresolution libraries
 * config/            - capistrano deployment files
 * spec/              - tests
 * data/schemas       - where cached schemas live
 * data/collections   - where collections, and information about submitted documents for a collection, live
 * logs/              - you can point you web server here, or use the built in logging (uses logs/xmlresolution.log)
 * tmp/               - phusion writes the restart.txt file here.  Rake has a restart target for this, capistrano uses it. 


Usage
-----

The following assumes you've a running server at xmlresolution.example.com.
There are built-in test forms for exploring the system; see http://xmlresolution.example.com/ for
instructions.  The following models how your RESTful clients should access the service.

 * Create a collection (some versions of curl require you to use an empty document):
	 
	curl --upload-file /dev/null -X PUT http://xmlresolution.example.com/ieids/collection-1
	
 * Submit some XML documents to it (note trailing slash):
	
	curl -F xmlfile=@myfile.xml http://xmlresolution.example.com/ieids/collection-1/	
	curl -F xmlfile=@myotherfile.xml http://xmlresolution.example.com/ieids/collection-1/
	
 * Get the tarfile of the associated schemas
	
	curl http://xmlresolution.example.com/ieids/collection-1/
	


Documentation
-------------
See the root of the running webservice for instructions on use; there is
a Rake task that will install the rdocs under public/rdoc.


