# frozen_string_literal: true
#
class DiagramProperties < ActiveRecord::Base
  validates :position, length: { is: 2 }
end

# == Schema Information
#
# Table name: diagram_properties
#
#  id             :bigint           not null, primary key
#  node_type      :string
#  position       :integer          default(["0", "0"]), is an Array
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  node_record_id :bigint
#  user_id        :bigint           not null
#
# Indexes
#
#  index_diagram_props_on_user_id_and_node_record_id_and_node_type  (user_id,node_record_id,node_type) UNIQUE
#
