require 'rubygems'
require 'open-uri'
require 'pstore'
require 'pp'

Username  = ARGV[0]
$store = PStore.new("urls.#{Username}.pstore")

raise "supply a username" if Username.nil? or Username.empty?

blogs = []
$store.transaction do
  blogs = $store.roots
end

blogs.each do | blog | 
  $store.transaction do
    next unless $store[blog]
    puts blog
    STDOUT.flush
    begin
      f = open $store[blog]
      s = f.read
      if(s =~ /<title>FreeMyFeed Error \(401\)<\/title>/)
        raise "broken feed"
      end
    rescue
      puts "FAILURE: #{blog} => #{$store[blog]}"
      $store[blog] = nil
    end
  end
end
