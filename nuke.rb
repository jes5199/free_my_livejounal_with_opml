require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'pstore'
require 'net/http'
require 'uri'
#
# Usage:
# ruby nuke.rb username friendname
# 
# removes a freemyfeed url from the store
# next run of friends.rb will replace it

Username = ARGV[0]
store = PStore.new("urls.#{Username}.pstore")

store.transaction do
  url = "http://#{ARGV[1]}.livejournal.com/data/rss?auth=digest"
  p store[url]
  store[url] = nil
end
