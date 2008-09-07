# Usage:
# ruby friends.rb username password export.opml > import.opml
#
#
#
# TODO: download feeds and detect errors (some percentage of freemyfeed urls are born broken)
# TODO: use canonical lj names instead of urlized names in the titles

require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'pstore'
require 'net/http'
require 'uri'
require 'builder'
require 'cgi'

Username  = ARGV[0]
Password  = ARGV[1]
OPMLInput = ARGV[2..-1]
FoafURI = "http://#{Username}.livejournal.com/data/foaf"
$store = PStore.new("urls.#{Username}.pstore")

class OutlineItem
  attr_reader :title, :blog_url
  
  def initialize(title, blog_url)
    @title = title
    @blog_url = blog_url
  end

  def rss_url
    blog_url + "data/rss"
  end 

  def private_url
    private_url = "http://pipes.yahoo.com/pipes/pipe.run?_id=EIdu0pV73RGzFD2ebbsjiw&_render=rss&rss=#{CGI.escape magic_url}"
  end

  def magic_url
    $store.transaction do
      if ! $store[secure_rss_url]
        sleep 0.5
        free_my_feed_page = Net::HTTP.post_form(
                              URI.parse('http://freemyfeed.com/free'),
                              {'url'=>secure_rss_url, 'user'=> Username, 'pass' => Password}
                            ).body
        magic_url = Hpricot(free_my_feed_page).search("#urlbox").text
        $store[secure_rss_url] = magic_url
        STDERR.puts " #{secure_rss_url} => #{magic_url} "
      end
      return $store[secure_rss_url]
    end
  end

  def secure_rss_url
    rss_url + "?auth=digest"
  end
end

outline = Hash.new{ |h,k| h[k] = [] }

# FOAF parsing
begin
  open FoafURI do |foaf_stream|
    doc = Hpricot.XML foaf_stream

    doc.search("foaf:weblog").each do | blog |
      folder_title = "livejournal_friends"
      blog_url = blog.attributes["rdf:resource"]
      user = blog_url.sub(/http:\/\//, "").sub(/\..*/, "") #FIXME: get from FOAF

      # store items in outline
      outline[folder_title].push OutlineItem.new(user, blog_url)
    end
  end
rescue
  STDERR.puts "sorry, no foaf today"
end

# OPML parsing
if OPMLInput and OPMLInput.length > 0
  OPMLInput.each do | opml_filename |
    puts opml_filename
    open opml_filename do |opml_stream|
      doc = Hpricot.XML opml_stream

      doc.search("body/outline").each do | folder |
        folder_title = folder.attributes["title"]
        folder.search("outline").each do | blog |
          blog_url = blog.attributes["htmlUrl"]
          next if blog_url !~ /\.livejournal\.com/
          title = blog.attributes["title"].sub(/\s*\[PROTECTED\]$/, "")

          # store items in outline
          outline[folder_title].push OutlineItem.new(title, blog_url)
        end
      end
    end
  end
end

# XML generation
xml = Builder::XmlMarkup.new(:target => STDOUT)
xml.instruct!
xml.opml(:version => "1.0") do
  xml.head do
    xml.title("subscriptions in Google Reader")
  end
  xml.body do
    outline.each do | folder, list | 
      xml.outline(:title => folder, :text => folder) do
        list.each do | item |
          item.instance_eval do
            xml.outline(:text => title, :title => title, :type => "rss", :xmlUrl => rss_url, :htmlUrl => blog_url)
            xml.outline(:text => "#{title} [PROTECTED]", :title => "#{title} [PROTECTED]", :type => "rss", :xmlUrl => private_url, :htmlUrl => blog_url)
          end
        end

      end
    end
  end
end
xml.comment!("created by free_my_livejounal_with_opml, by jes5199, under the GPL3")
