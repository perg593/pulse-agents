# frozen_string_literal: true
FactoryBot.define do
  factory :invitation_diagram_properties, class: "DiagramProperties" do
    node_type { "Invitation" }
    position { [25, 50] }
  end

  factory :thank_you_diagram_properties, class: "DiagramProperties" do
    node_type { "ThankYou" }
    position { [100, 200] }
  end

  factory :question_diagram_properties, class: "DiagramProperties" do
    node_type { "Question" }
    position { [200, 300] }
  end
end
