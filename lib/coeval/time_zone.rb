require 'tzinfo'
require 'date'

module Coeval
  module TimeZone
    def self.default
      ENV.fetch('DEFAULT_TIMEZONE', 'America/Santiago')
    end

    def self.zone(identifier)
      TZInfo::Timezone.get(identifier)
    end

    def self.local(time, identifier)
      zone(identifier).to_local(time.to_time)
    end

    def self.parse(value, identifier)
      # datetime-local has no offset: interpret its wall clock in the course zone.
      raise ArgumentError unless value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)
      date = DateTime.iso8601(value)
      wall_clock = Time.utc(date.year, date.month, date.day, date.hour, date.minute, date.second)
      zone(identifier).local_to_utc(wall_clock, nil).getlocal
    end
  end
end
