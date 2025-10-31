# frozen_string_literal: true

module Control
  module DeviceDataTriggerHelper
    def device_data_matcher_options
      {
        "Equals" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS,
        "Does Not Equal" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_NOT,
        "Contains" => DeviceDataTrigger::DEVICE_DATA_MATCHER_CONTAINS,
        "Does Not Contain" => DeviceDataTrigger::DEVICE_DATA_MATCHER_DOES_NOT_CONTAIN,
        "Exists" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_TRUE,
        "Does Not Exist" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_NOT_TRUE,
        "Is Greater Than" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_MORE_THAN,
        "Is Greater Than or Equals to" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_EQUAL_OR_MORE_THAN,
        "Is Less Than" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_EQUAL_OR_LESS_THAN,
        "Is Less Than or Equals to" => DeviceDataTrigger::DEVICE_DATA_MATCHER_IS_LESS_THAN
      }
    end
  end
end
