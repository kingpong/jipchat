#!/usr/bin/env ruby
require 'rubygems'
require 'hashie'
require 'hipchat'
require 'logger'
require 'open-uri'
require 'openssl'
require 'pry'
require 'rss'
require 'yaml'

config_file = File.dirname(__FILE__) + "/config.yaml"
config = Hashie::Mash[ YAML.load(File.open(config_file)) ]

config.jira.poll_frequency ||= 30
config.hipchat.label       ||= "JIRA"
config.hipchat.color       ||= "purple"

hipchat = HipChat::Client.new(config.hipchat.token)[config.hipchat.room]

seen = {}
first_pass = true

while true
  begin
    xml = open(config.jira.feed_url, http_basic_authentication: [config.jira.username,config.jira.password], ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
    feed = RSS::Parser.parse(xml,false)

    feed.items.sort_by {|item| item.published.content }.each do |item|
      next if seen[item.id.content]
      seen[item.id.content] = true

      # Don't report any feed items that existed at app startup time. We
      # only want to know about *new* events.
      next if first_pass

      message = [item.title, item.content].compact.map(&:content).join("<br/>")
      hipchat.send(config.hipchat.label, message, color: config.hipchat.color)
    end
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
  end

  first_pass = false

  sleep config.jira.poll_frequency
end
