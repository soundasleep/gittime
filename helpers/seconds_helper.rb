require "chronic_duration"

module SecondsHelper
  def seconds_in(string)
    return nil if string.blank?
    ChronicDuration::parse(string)
  end

  def default_before
    seconds_in("1 hour")
  end

  def default_after
    seconds_in("1 hour")
  end
end
