#!/usr/bin/env ruby
require 'singleton'

class Chrono
    include Singleton
    @@internal_time = nil

    def initialize
        enable_truth
    end

    def self.now
        if @@internal_time != nil
            return @@internal_time
        end
        return DateTime.now
    end

    def set_now datetime
        @@internal_time = datetime
    end

    def enable_truth
        @@internal_time = nil
    end
end
