# Copyright 2010 Savonix Corporation
# Author Albert L. Lash, IV
# License MIT
module Rack
  class XSLView

    class XSLViewError < StandardError ; end

    def initialize(app, options)
      @app = app
      @options = {:myxsl => nil}.merge(options)
      if @options[:myxsl].nil?
        require 'rexml/document'
        @xslt = XML::XSLT.new()
        @xslt.xsl = REXML::Document.new '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://www.w3.org/1999/xhtml"><xsl:import href="http://github.com/docunext/1bb02b59/raw/master/standard.html.xsl"/><xsl:output method="xml" encoding="UTF-8" omit-xml-declaration="no" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" indent="yes"/></xsl:stylesheet>'
      else
        @xslt = @options[:myxsl]
      end
    end

    def call(env)
      # No matter what, @app will be called
      status, headers, body = @app.call(env)

      # If setup includes paths to exclude from xslt processing, check them
      checknoxsl(env) if @options[:noxsl]

      # Obtain entire request body, check to make sure it can be processed
      myxml = getResponse(body)

      # Should XSL file be reloaded?
      if @options[:reload] == true
        @xslt     = XML::XSLT.new()
        @xslt.xsl = REXML::Document.new @options[:xslfile]
      end

      # Set XML for stylesheet
      @xslt.xml = myxml

      # If setup includes env vars to pass through as params, do so
      unless @options[:passenv].nil?
        @myhash = {}
        @options[:passenv].each { |envkey|
          # Does env var exist?
          @myhash[envkey] = "#{mp}" if (mp = env[envkey])
        }
        @xslt.parameters = @myhash unless @myhash.empty?
      end

      # Perform the transformation
      newbody = Array.[](@xslt.serve)

      # If we've made it this far, we can alter the headers
      headers.delete('Content-Length')
      headers['Content-Length'] = newbody[0].length.to_s
      [status, headers, newbody]

    rescue XSLViewError
      # TODO Logging: "Rack XSLView not processed" if env['RACK_ENV'] == 'development'
      [status, headers, body]
    end

    private
    def checknoxsl(env)
      @options[:noxsl].each { |path|
        raise XSLViewError if env["PATH_INFO"].index(path)
      }
    end
    def getResponse(body)
      raise XSLViewError if body.nil?
      newbody = ''
      body.each { |part|
        # Only check the first chunk to ensure 1) its not HTML and 2) its XML
        checkForXml(part) if newbody.empty?
        newbody << part.to_s
      }
      return newbody
    end
    def checkForXml(x)
      # Abort processing if content cannot be processed by libxslt
      raise XSLViewError if x[0,1] != '<'
      if @options[:excludehtml] == true
        raise XSLViewError if x.include? '<html'
      end
    end

    def choosesheet(env)
      # Not used yet, this may be used to match stylesheets with paths
      @options[:xslhash].each_key { |path|
        if env["PATH_INFO"].index(path)
          return @options[:xslhash][path]
        end
      }
      return false
    end
  end
end

