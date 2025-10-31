# frozen_string_literal: true

module GammaClient
  require_relative "http"

  # Base URL for Gamma API
  GAMMA_API_BASE_URL = "https://public-api.gamma.app/v0.2"

  # ---------------------------------------------------------------------------
  # Generate a Gamma presentation
  # POST https://public-api.gamma.app/v0.2/generations
  # ---------------------------------------------------------------------------
  def self.generate_gamma(
    input_text: nil,
    text_mode: "preserve",
    format: nil,
    num_cards: nil,
    card_split: nil,
    image_options: { source: "noImages" },
    card_options: { dimensions: "16x9" },
    sharing_options: { workspaceAccess: "fullAccess", externalAccess: "edit" },
    logger: Rails.logger
  )
    url = "#{GAMMA_API_BASE_URL}/generations"

    body = {
      textMode: text_mode,
      cardOptions: card_options,
      sharingOptions: sharing_options
    }

    # Add inputText if provided
    body[:inputText] = input_text if input_text.present?

    # Add optional parameters only if provided (let API use defaults otherwise)
    body[:format] = format if format.present?
    body[:numCards] = num_cards if num_cards.present?
    body[:cardSplit] = card_split if card_split.present?

    # Add imageOptions if provided
    body[:imageOptions] = image_options if image_options.present?

    response = GammaClient::HTTP.json_post(url, body, logger)

    # Return just the generation ID for convenience
    response["generationId"] if response
  end

  # ---------------------------------------------------------------------------
  # Get generation status and URLs
  # GET https://public-api.gamma.app/v0.2/generations/{generationId}
  # ---------------------------------------------------------------------------
  def self.get_generation_status(generation_id, logger: Rails.logger)
    url = "#{GAMMA_API_BASE_URL}/generations/#{generation_id}"

    GammaClient::HTTP.json_get(url, logger)
  end

  # ---------------------------------------------------------------------------
  # Convenience method to check if generation is completed
  # ---------------------------------------------------------------------------
  def self.generation_completed?(generation_id, logger: Rails.logger, handle_errors: true)
    status = get_generation_status(generation_id, logger: logger)
    status && status["status"] == "completed"
  rescue GammaClient::HTTP::GammaError
    handle_errors ? false : raise
  end

  # ---------------------------------------------------------------------------
  # Get the Gamma URL once generation is completed
  # ---------------------------------------------------------------------------
  def self.get_gamma_url(generation_id, logger: Rails.logger)
    status = get_generation_status(generation_id, logger: logger)
    status["gammaUrl"] if status && status["status"] == "completed"
  end
end
