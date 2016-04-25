#!/usr/bin/ruby

require 'faraday'
require 'nokogiri'

home = ENV['HOME']

filename = home + '/.packt_checker'

contents = []

if File.file? filename
  f = File.open(filename, 'r') do |f|
    f.each_line do |line|
      contents << line.strip
    end
  end
  f.close
end

baseurl = 'https://www.packtpub.com'
path = '/packt/offers/free-learning'
client = Faraday.new(:url => baseurl)

html = client.get(path).body

page = Nokogiri::HTML(html)

title = page.css('div[class=dotd-title] h2')[0].text.strip

if contents.include? title
  print "No new free books\n"
else
  print "new free books at: #{baseurl + path}\n"
  File.open(filename, 'a') do |f|
    f.puts title
    f.close
  end
end
