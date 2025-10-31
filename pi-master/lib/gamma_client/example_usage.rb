# frozen_string_literal: true

# Example usage of GammaClient
#
# This file demonstrates how to use the Gamma API client to:
# 1. Generate a new Gamma presentation
# 2. Check the status of a generation
# 3. Get the final Gamma URL

require_relative "gamma_client"

# Example 1: Generate a new Gamma presentation
def generate_presentation_example
  puts "Generating a new Gamma presentation..."

  generation_id = GammaClient.generate_gamma(
    text_mode: "generate",
    format: "presentation",
    num_cards: "10",
    card_split: "auto",
    text_options: { amount: "medium", language: "en" },
    image_options: { source: "aiGenerated" }
  )

  if generation_id
    puts "Generation started! Generation ID: #{generation_id}"
    return generation_id
  else
    puts "Failed to start generation"
    return nil
  end
end

# Example 2: Check generation status
def check_status_example(generation_id)
  puts "Checking status for generation: #{generation_id}"

  status = GammaClient.get_generation_status(generation_id)

  if status
    puts "Status: #{status['status']}"
    puts "Gamma URL: #{status['gammaUrl']}" if status['gammaUrl']
  else
    puts "Failed to get status"
  end

  return status
end

# Example 3: Poll for completion (frontend responsibility)
def poll_for_completion_example(generation_id)
  puts "Polling for generation #{generation_id} to complete..."
  puts "Note: In a real application, this would be handled by the frontend with setInterval"

  loop do
    status = GammaClient.get_generation_status(generation_id)

    if status && status['status'] == 'completed'
      puts "Generation completed!"
      puts "Gamma URL: #{status['gammaUrl']}"
      return status
    elsif status && status['status'] == 'failed'
      puts "Generation failed!"
      return nil
    else
      puts "Still processing... (status: #{status['status'] if status})"
      sleep(5) # Wait 5 seconds before checking again
    end
  end
end

# Example 4: Complete workflow
def complete_workflow_example
  puts "=== Complete Gamma Generation Workflow ==="

  # Step 1: Generate
  generation_id = generate_presentation_example
  return unless generation_id

  # Step 2: Poll for completion (in real app, this would be frontend polling)
  result = poll_for_completion_example(generation_id)

  if result
    puts "=== Workflow completed successfully ==="
    puts "Your Gamma presentation is ready at: #{result['gammaUrl']}"
  else
    puts "=== Workflow failed ==="
  end
end

# Uncomment the line below to run the complete workflow example
# complete_workflow_example
