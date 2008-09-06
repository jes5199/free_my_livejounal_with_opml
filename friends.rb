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
require 'builder'

Username = ARGV[0]
Password = ARGV[1]
FoafURI = "http://#{Username}.livejournal.com/data/foaf"
store = PStore.new("urls.#{Username}.pstore")

open FoafURI do |foaf_stream|
  doc = Hpricot foaf_stream

  xml = Builder::XmlMarkup.new
  xml.instruct!
  xml.opml(:version => "1.0") do
    xml.head do
      xml.title("subscriptions in Google Reader")
    end
    xml.body do
      xml.outline(:title => "livejournal" :text => "livejournal") do

        doc.search("foaf:weblog").each do | blog |
          blog_url = blog.attributes["rdf:resource"]
          rss_url = blog_url + "data/rss"
          secure_rss_url = rss_url + "?auth=digest"
          magic_url = nil
          store.transaction do
            if ! store[secure_rss_url]
              sleep 0.5
              free_my_feed_page = Net::HTTP.post_form(
                                    URI.parse('http://freemyfeed.com/free'),
                                    {'url'=>secure_rss_url, 'user'=> Username, 'pass' => Password}
                                  ).body
              magic_url = Hpricot(free_my_feed_page).search("#urlbox").text
              store[secure_rss_url] = magic_url
              STDERR.puts " #{secure_rss_url} => #{magic_url} "
            end
            magic_url = store[secure_rss_url]
          end
          private_url = "http://pipes.yahoo.com/pipes/pipe.run?_id=EIdu0pV73RGzFD2ebbsjiw&_render=rss&rss=#{URI.escape magic_url}"
          user = blog_url.sub(/http:\/\//, "").sub(/\..*/, "") #FIXME: get from FOAF
          xml.outline(:text => user, :title => user, :type => "rss", :xmlUrl => rss_url, :htmlUrl => blog_url)
          xml.outline(:text => "#{user} [PROTECTED]", :title => "#{user} [PROTECTED]", :type => "rss", :xmlUrl => private_url, :htmlUrl => blog_url)
        end

      end
    end
  puts xml.comment!("created by free_my_livejounal_with_opml, by jes5199, under the GPL3")
end
