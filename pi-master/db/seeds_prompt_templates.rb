# frozen_string_literal: true

# Seed file for Prompt Templates
# Run with: rails runner db/seeds_prompt_templates.rb

puts "Creating prompt templates..."

# Create the default template
PromptTemplate.find_or_create_by(name: "Pulse Insights Data Analysis Framework v3.0") do |template|
  template.content = <<~CONTENT
    Provide a comprehensive analysis of the survey data following the Pulse Insights framework.#{' '}

    Focus on:
    - Key insights and trends
    - Customer satisfaction metrics
    - User behavior patterns
    - Actionable recommendations for stakeholders
    - Strategic next steps

    Structure the analysis with clear sections for Executive Summary, Key Findings, Recommendations, and Next Steps.
  CONTENT
  template.is_default = true
end

puts "✓ Default template created/updated"

# Create additional templates
templates = [
  {
    name: "Executive Summary v2.1",
    content: <<~CONTENT
      Create an executive-level summary of the survey findings.

      Include:
      - High-level insights and trends
      - Most important metrics
      - Strategic recommendations for business decisions
      - Risk assessment and opportunities

      Keep the language executive-friendly and focus on business impact.
    CONTENT
  },
  {
    name: "Customer Experience Deep Dive",
    content: <<~CONTENT
      Analyze the customer experience aspects of the survey data.

      Focus on:
      - Customer satisfaction drivers
      - Pain points and friction areas
      - Experience improvement opportunities
      - Customer journey insights
      - Service quality metrics

      Provide actionable recommendations for CX improvements.
    CONTENT
  },
  {
    name: "Product Feedback Analysis",
    content: <<~CONTENT
      Focus on product-related feedback from the survey.

      Analyze:
      - Feature requests and suggestions
      - Usability issues and improvements
      - Product satisfaction metrics
      - Feature adoption patterns
      - Product-market fit indicators

      Provide prioritized recommendations for product development.
    CONTENT
  }
]

templates.each do |template_data|
  template = PromptTemplate.find_or_create_by(name: template_data[:name]) do |t|
    t.content = template_data[:content]
    t.is_default = false
  end
  puts "✓ Template '#{template.name}' created/updated"
end

puts "\nPrompt templates seeding completed!"
puts "Total templates: #{PromptTemplate.count}"
puts "Default template: #{PromptTemplate.default.first&.name}"
