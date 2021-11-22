require "date"

module DateHelper
  def print_date(date)
    date.strftime(options[:date_format])
  end
end
