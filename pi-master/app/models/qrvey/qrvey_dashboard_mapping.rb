# frozen_string_literal: true

# Maps dashboards on Qrvey to our console app.
# We identify Qrvey dashboards by name.
class QrveyDashboardMapping < ActiveRecord::Base
  audited

  validates :qrvey_name, :pi_name, :position, presence: true
  validates :qrvey_name, :pi_name, :position, uniqueness: true
end

# == Schema Information
#
# Table name: qrvey_dashboard_mappings
#
#  id         :bigint           not null, primary key
#  pi_name    :string
#  position   :integer
#  qrvey_name :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_qrvey_dashboard_mappings_on_pi_name     (pi_name) UNIQUE
#  index_qrvey_dashboard_mappings_on_position    (position) UNIQUE
#  index_qrvey_dashboard_mappings_on_qrvey_name  (qrvey_name) UNIQUE
#
