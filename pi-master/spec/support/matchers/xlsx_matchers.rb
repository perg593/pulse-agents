# frozen_string_literal: true
require 'rspec/expectations'

module XslsMatchers
  RSpec::Matchers.define :have_header_cells do |cell_values|
    match do |worksheet|
      worksheet.rows[0].cells.map(&:value) == cell_values
    end

    failure_message do |actual|
      "Expected #{actual.rows[0].cells.map(&:value)} to be #{expected}"
    end
  end

  RSpec::Matchers.define :have_cells do |expected|
    match do |worksheet|
      worksheet.rows[@index].cells.map(&:value) == expected
    end

    chain :in_row do |index|
      @index = index
    end

    failure_message do |actual|
      "Expected #{actual.rows[@index].cells.map(&:value)} to include #{expected} at row #{@index}."
    end
  end

  RSpec::Matchers.define :have_value do |expected|
    match do |worksheet|
      worksheet.rows[@row_index].cells[@column_index].value == expected
    end

    chain :at do |row_index, column_index|
      @row_index = row_index
      @column_index = column_index
    end

    failure_message do |actual|
      "Expected #{actual.rows[@row_index].cells[@column_index].value} to equal #{expected} at (#{@row_index}, #{@column_index})"
    end
  end
end
