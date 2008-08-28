# Usage:
# ruby friends.rb username password > import.opml
#
#
#
# TODO: use XML Builder or something other than strings
# TODO: download feeds and detect errors (some percentage of freemyfeed urls are born broken)
# TODO: use canonical lj names instead of urlized names in the titles

require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'pstore'
require 'net/http'
require 'uri'

Username = ARGV[0]
Password = ARGV[1]
FoafURI = "http://#{Username}.livejournal.com/data/foaf"
store = PStore.new("urls.#{Username}.pstore")

open FoafURI do |foaf_stream|
  doc = Hpricot foaf_stream

  puts <<-DOC
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
    <head>
        <title>subscriptions in Google Reader</title>
    </head>
    <body>
        <outline title="livejournal" text="livejournal">
  DOC

  doc.search("foaf:weblog").each do | blog |
    blog_url = blog.attributes["rdf:resource"]
    atom_url = blog_url + "data/atom?auth=digest"
    magic_url = nil
    store.transaction do
      if ! store[atom_url]
        sleep 0.5
        free_my_feed_page = Net::HTTP.post_form(
                              URI.parse('http://freemyfeed.com/free'),
                              {'url'=>atom_url, 'user'=> Username, 'pass' => Password}
                            ).body
        magic_url = Hpricot(free_my_feed_page).search("#urlbox").text
        store[atom_url] = magic_url
        STDERR.puts " #{atom_url} => #{magic_url} "
      end
      magic_url = store[atom_url]
    end
    html_url = atom_url.sub(/data\/atom\?auth=digest/, "")
    user = html_url.sub(/http:\/\//, "").sub(/\..*/, "")
    puts <<-DOC
            <outline text="#{user}" title="#{user}" type="rss"
                xmlUrl="#{magic_url}" htmlUrl="#{html_url}"/>
    DOC
  end

  puts <<-DOC
        </outline>
    </body>
</opml>
    DOC
end
