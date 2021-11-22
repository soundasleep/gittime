require "date"
require "active_support/time"

module DateHelper
  def print_date(date)
    date.in_time_zone(options[:time_zone]).strftime(options[:date_format])
  end
end
