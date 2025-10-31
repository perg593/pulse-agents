# frozen_string_literal: true

module Google
  class GoogleSlidesRequestBuilder
    TARGET_URL_TEMPLATE_COLORS = { red: 0.533, green: 0.518, blue: 0.612 }.freeze

    # Create a request to duplicate an object
    # @param object_id [String] The ID of the object to duplicate
    # @return [Hash] The duplicate object request
    def build_duplicate_object_request(object_id)
      {
        duplicate_object: {
          object_id_prop: object_id
        }
      }
    end

    # Create a request to delete an object
    # @param object_id [String] The ID of the object to delete
    # @return [Hash] The delete object request
    def build_delete_object_request(object_id)
      {
        delete_object: {
          object_id_prop: object_id
        }
      }
    end

    # Create a request to replace an image
    # @param image_object_id [String] The ID of the image object to replace
    # @param image_url [String] The URL of the new image
    # @return [Hash] The replace image request
    def build_replace_image_request(image_object_id, image_url)
      {
        replace_image: {
          image_object_id: image_object_id,
          url: image_url
        }
      }
    end

    # Build a request to delete text from a text element
    # @param text_element_id [String] The ID of the text element
    # @return [Hash] The delete text request
    def build_delete_text_request(text_element_id)
      {
        delete_text: {
          object_id_prop: text_element_id,
          text_range: {
            type: "ALL"
          }
        }
      }
    end

    # Build a request to delete text from a table cell
    # @param table_element_id [String] The ID of the table element
    # @param cell_location [Hash] The location of the cell
    # @return [Hash] The delete text request
    def build_delete_cell_text_request(table_element_id, cell_location)
      {
        delete_text: {
          object_id_prop: table_element_id,
          text_range: {
            type: "ALL"
          },
          cell_location: {
            table_object_id: table_element_id,
            row_index: cell_location[:row_index],
            column_index: cell_location[:column_index]
          }
        }
      }
    end

    # Build a request to insert text into a text element
    # @param text_element_id [String] The ID of the text element
    # @param text [String] The text to insert
    # @return [Hash] The insert text request
    def build_insert_text_request(text_element_id, text)
      {
        insert_text: {
          object_id_prop: text_element_id,
          insertion_index: 0,
          text: text
        }
      }
    end

    # Build a request to insert text into a table cell
    # @param table_element_id [String] The ID of the table element
    # @param cell_location [Hash] The location of the cell
    # @param insertion_index [Integer] The index at which to insert the text
    # @param text [String] The text to insert
    # @return [Hash] The insert text request
    def build_insert_cell_text_request(table_element_id, cell_location, insertion_index, text)
      {
        insert_text: {
          object_id_prop: table_element_id,
          insertion_index: insertion_index,
          text: "#{text}\n",
          cell_location: {
            table_object_id: table_element_id,
            row_index: cell_location[:row_index],
            column_index: cell_location[:column_index]
          }
        }
      }
    end

    # Build a request to update text style
    # @param table_element [Google::Apis::SlidesV1::PageElement] The table element
    # @param cell_location [Hash] The location of the cell
    # @param insertion_index [Integer] The index at which the text was inserted
    # @param text [String] The text to style
    # @param style [Hash] The style to apply
    # @param content_index [Integer] The index of the content in the formatted content array
    # @return [Hash] The update text style request
    def build_update_style_request(table_element:, cell_location:, insertion_index:, text:, style:, content_index:)
      style_args = style.to_h
      style_args[:foreground_color] = { opaque_color: { rgb_color: content_index.even? ? TARGET_URL_TEMPLATE_COLORS : { red: 0.0, green: 0.0, blue: 0.0 } } }

      {
        update_text_style: {
          object_id_prop: table_element.object_id_prop,
          cell_location: {
            table_object_id: table_element.object_id_prop,
            row_index: cell_location[:row_index],
            column_index: cell_location[:column_index]
          },
          text_range: {
            type: "FIXED_RANGE",
            start_index: insertion_index,
            end_index: insertion_index + text.length
          },
          style: style_args,
          fields: style_args.keys.map(&:to_s).map { |style_key| style_key.camelize(:lower) }.join(",")
        }
      }
    end
  end
end
