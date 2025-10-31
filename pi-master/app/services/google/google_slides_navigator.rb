# frozen_string_literal: true

require 'google/apis/slides_v1'

module Google
  module GoogleSlidesNavigator
    # Find a text element in a slide that contains the specified text
    # @param slide [Google::Apis::SlidesV1::Page] The slide to search in
    # @param search_text [String] The text to search for
    # @return [Google::Apis::SlidesV1::PageElement, nil] The found text element or nil if not found
    def find_text_element_in_slide(slide, search_text)
      slide.page_elements.each do |element|
        next unless element.shape&.text
        element.shape.text.text_elements.each do |text_element|
          next unless text_element.text_run&.content&.include?(search_text)
          Rails.logger.info("Found '#{search_text}' text element with ID: #{element.object_id_prop}")

          return element
        end
      end

      nil
    end

    # Find a slide containing specific text
    # @param presentation [Google::Apis::SlidesV1::Presentation] The presentation to search
    # @param search_text [String] The text to search for
    # @return [Google::Apis::SlidesV1::Page, nil] The slide containing the text, or nil if not found
    def find_slide_with_text(presentation, search_text)
      Rails.logger.info("Searching for slide with text: #{search_text}")

      presentation.slides.each do |slide|
        Rails.logger.info("Checking slide with ID: #{slide.object_id_prop}")

        next unless slide.page_elements # Skip if no elements
        slide.page_elements.each do |element|
          # Check if this is a table
          if element.table
            Rails.logger.info("Found table with #{element.table.table_rows.length} rows")

            return slide if table_contains_text?(element.table, search_text)
          end

          # Check regular text elements
          return slide if element.shape && shape_contains_text?(element.shape, search_text)
        end
      end

      Rails.logger.warn("No slide found containing text: #{search_text}")
      nil
    rescue StandardError => e
      Rails.logger.error("Error finding slide with text: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      nil
    end

    # Find a text element with a specific description in a slide
    # @param slide [Google::Apis::SlidesV1::Page] The slide to search in
    # @param description [String] The description to search for
    # @return [Google::Apis::SlidesV1::PageElement, nil] The found text element, or nil if not found
    def find_text_element_with_description(slide, description)
      Rails.logger.info("Inspecting all elements on the slide for text elements with description: #{description}")

      text_element = slide.page_elements.select(&:shape).detect { |elem| elem.description == description }
      Rails.logger.warn("Could not find text element with description: #{description}") unless text_element

      text_element
    end

    # Find an image element with a specific description in a slide
    # @param slide [Google::Apis::SlidesV1::Page] The slide to search in
    # @param description [String] The description to search for
    # @return [Google::Apis::SlidesV1::PageElement, nil] The found image element, or nil if not found
    def find_image_element_with_description(slide, description)
      Rails.logger.info("Inspecting all elements on the slide for image elements...")

      image_element = slide.page_elements.select(&:image).detect { |img_elem| img_elem.description == description }
      Rails.logger.warn("Could not find image element in CANVAS_SLIDE") unless image_element

      image_element
    end

    # Find a cell containing specific text in a table
    # @param table [Google::Apis::SlidesV1::Table] The table to search in
    # @param search_text [String] The text to search for
    # @return [Google::Apis::SlidesV1::TableCell, nil] The found cell or nil if not found
    def find_cell_with_text(table, search_text)
      table.table_rows.each_with_index do |row, row_index|
        row.table_cells.each_with_index do |cell, col_index|
          next unless cell&.text&.text_elements

          cell.text.text_elements.each do |text_element|
            next unless text_element.text_run&.content
            next unless text_element.text_run.content.include?(search_text)

            Rails.logger.info("Found text in cell at row #{row_index}, column #{col_index}")

            return cell
          end
        end
      end

      nil
    end

    # Find a table element in a slide
    # @param slide [Google::Apis::SlidesV1::Page] The slide to search in
    # @return [Google::Apis::SlidesV1::PageElement, nil] The found table element, or nil if not found
    def find_table_element(slide)
      table_element = slide.page_elements.find(&:table)

      Rails.logger.warn("Could not find table element") unless table_element

      table_element
    end

    # Get the location of a cell in a table
    # @param table_element [Google::Apis::SlidesV1::PageElement] The table element
    # @param cell [Google::Apis::SlidesV1::TableCell] The cell to locate
    # @return [Hash] Hash containing table_object_id, row_index, and column_index
    def get_cell_location(table_element, cell)
      cell_location = {
        table_object_id: table_element.object_id_prop,
        row_index: cell.location.row_index,
        column_index: cell.location.column_index
      }

      if cell_location[:column_index].nil?
        table_element.table.table_rows[cell_location[:row_index]].table_cells.each_with_index do |c, col_idx|
          if c == cell
            cell_location[:column_index] = col_idx
            break
          end
        end
      end

      Rails.logger.info("Cell location: #{cell_location.inspect}")

      cell_location
    end

    private

    # Check if a table contains specific text
    # @param table [Google::Apis::SlidesV1::Table] The table to search in
    # @param search_text [String] The text to search for
    # @return [Boolean] True if the text is found, false otherwise
    def table_contains_text?(table, search_text)
      find_cell_with_text(table, search_text).present?
    end

    # Check if a shape contains specific text
    # @param shape [Google::Apis::SlidesV1::Shape] The shape to search in
    # @param search_text [String] The text to search for
    # @return [Boolean] True if the text is found, false otherwise
    def shape_contains_text?(shape, search_text)
      shape.text&.text_elements&.any? { |text_element| text_element.text_run&.content&.include?(search_text) }
    end
  end
end
