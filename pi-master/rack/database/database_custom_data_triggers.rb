# frozen_string_literal: true
#
module Rack
  module DatabaseCustomDataTriggers
    def custom_data_is(trigger, custom_data)
      custom_data[trigger['device_data_key']].to_s == trigger['device_data_value'].to_s
    end

    def custom_data_is_not(trigger, custom_data)
      custom_data[trigger['device_data_key']].to_s != trigger['device_data_value'].to_s
    end

    def custom_data_contains(trigger, custom_data)
      custom_data[trigger['device_data_key']].to_s.include? trigger['device_data_value'].to_s
    end

    def custom_data_does_not_contain(trigger, custom_data)
      !custom_data[trigger['device_data_key']].to_s.include? trigger['device_data_value'].to_s
    end

    def custom_data_is_more_than(trigger, custom_data)
      !custom_data[trigger['device_data_key']].nil? && custom_data[trigger['device_data_key']].to_i > trigger['device_data_value'].to_i
    end

    def custom_data_is_equal_or_more_than(trigger, custom_data)
      !custom_data[trigger['device_data_key']].nil? && custom_data[trigger['device_data_key']].to_i >= trigger['device_data_value'].to_i
    end

    def custom_data_is_less_than(trigger, custom_data)
      !custom_data[trigger['device_data_key']].nil? && custom_data[trigger['device_data_key']].to_i < trigger['device_data_value'].to_i
    end

    def custom_data_is_equal_or_less_than(trigger, custom_data)
      !custom_data[trigger['device_data_key']].nil? && custom_data[trigger['device_data_key']].to_i <= trigger['device_data_value'].to_i
    end

    def custom_data_is_true(trigger, custom_data)
      custom_data.key? trigger['device_data_key']
    end

    def custom_data_is_not_true(trigger, custom_data)
      !custom_data.key? trigger['device_data_key']
    end
  end
end
