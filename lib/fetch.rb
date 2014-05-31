require 'uri'
require 'open-uri'
require 'singleton'

class Fetch
    include Singleton
    @@g_sanitize = true
    @@callback = nil

    def initialize
        @gg_sanitize = true
        @@callback = nil
    end

    # FIXME this callback stuff is shit. Gotta be able to do it better
    # XXX CALLBACKS ARE ONLY FOR TESTING. If you abuse this in non-testing
    #   code, you are a bad bad person.
    def set_callback(&block)
        @@callback = block
    end

    def nil_callback
        @@callback = nil
    end

    def global_sanitize=(truth)
        @@g_sanitize = truth
    end

    def self.openUrl(url, sanitize = nil)
        if (sanitize == nil && @@g_sanitize) || sanitize == true
            url = self.sanitize url
        end
        if @@callback != nil
            return @@callback.call(url)
        else
            return self.fetch(url)
        end
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
