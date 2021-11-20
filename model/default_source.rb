class DefaultSource
  include SecondsHelper

  attr_reader :before, :after

  def initialize(yaml)
    @before = seconds_in(yaml["before"]) || default_before
    @after = seconds_in(yaml["after"]) || default_after

    fail "Cannot have <= 0 before seconds for #{yaml}" if @before <= 0
    fail "Cannot have <= 0 after seconds for #{yaml}" if @after <= 0
  end

  private

end
