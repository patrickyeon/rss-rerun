#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

class Feed
    def self.fromUrl(url)
        Nokogiri::XML(open(url))
    end
end
