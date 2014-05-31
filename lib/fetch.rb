require 'uri'
require 'open-uri'
require 'singleton'

class Fetch
    include Singleton
    @@g_sanitize = true

    def initialize
        @gg_sanitize = true
    end

    def global_sanitize=(truth)
        @@g_sanitize = truth
    end

    def self.openUrl(url, sanitize = nil)
        if (sanitize == nil && @@g_sanitize) || sanitize == true
            url = self.sanitize url
        end
        return self.fetch(url)
    end

    def self.fetch url
        uri = URI.parse(url)
        if [URI::HTTP, URI::HTTPS].include? uri.class
            return uri.open
        end
        return File.open(url)
    end

    def self.sanitize(url)
        if [URI::HTTP, URI::HTTPS].include? URI.parse(url).class
            return url
        else
            return 'http://' + url
        end
    end
end
