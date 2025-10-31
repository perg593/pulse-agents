# Gamma API Client

A Ruby client for the Gamma API that follows the same patterns as the existing Qrvey client in this application.

## Setup

1. Add your Gamma API key to Rails credentials:

```bash
rails credentials:edit
```

Add the following to your credentials:

```yaml
gamma:
  api_key: your_gamma_api_key_here
```

2. The client will automatically load the API key from credentials via the initializer in `config/initializers/gamma_api.rb`.

## Usage

### Basic Generation

```ruby
# Generate a new Gamma presentation
generation_id = GammaClient.generate_gamma(
  text_mode: "generate",
  format: "presentation",
  num_cards: "10",
  card_split: "auto",
  text_options: { amount: "medium", language: "en" },
  image_options: { source: "aiGenerated" }
)

puts "Generation ID: #{generation_id}"
```

### Check Generation Status

```ruby
# Check if generation is completed
if GammaClient.generation_completed?(generation_id)
  gamma_url = GammaClient.get_gamma_url(generation_id)
  puts "Gamma URL: #{gamma_url}"
end

# Or get full status information
status = GammaClient.get_generation_status(generation_id)
puts "Status: #{status['status']}"
puts "Gamma URL: #{status['gammaUrl']}" if status['gammaUrl']
```

### Wait for Completion

```ruby
# Wait for generation to complete (with timeout)
begin
  result = GammaClient.wait_for_completion(generation_id, timeout_seconds: 300, check_interval: 10)
  puts "Generation completed! URL: #{result['gammaUrl']}"
rescue GammaClient::HTTP::GammaError => e
  puts "Error: #{e.message}"
end
```

### Complete Workflow Example

```ruby
# Generate and wait for completion in one workflow
generation_id = GammaClient.generate_gamma
if generation_id
  result = GammaClient.wait_for_completion(generation_id)
  puts "Your Gamma is ready at: #{result['gammaUrl']}"
end
```

## API Methods

### `generate_gamma(options = {})`

Generates a new Gamma presentation.

**Parameters:**
- `text_mode` (String): "generate" (default)
- `format` (String): "presentation" (default)
- `num_cards` (String): Number of cards, e.g., "10" (default)
- `card_split` (String): "auto" (default)
- `text_options` (Hash): Text generation options (default: `{ amount: "medium", language: "en" }`)
- `image_options` (Hash): Image generation options (default: `{ source: "aiGenerated" }`)
- `logger` (Logger): Logger instance (default: `Rails.logger`)

**Returns:** Generation ID (String) or nil on failure

### `get_generation_status(generation_id, logger: Rails.logger)`

Gets the status of a generation.

**Parameters:**
- `generation_id` (String): The generation ID
- `logger` (Logger): Logger instance (default: `Rails.logger`)

**Returns:** Hash with status information or nil on failure

### `generation_completed?(generation_id, logger: Rails.logger)`

Checks if a generation is completed.

**Parameters:**
- `generation_id` (String): The generation ID
- `logger` (Logger): Logger instance (default: `Rails.logger`)

**Returns:** Boolean

### `get_gamma_url(generation_id, logger: Rails.logger)`

Gets the Gamma URL if generation is completed.

**Parameters:**
- `generation_id` (String): The generation ID
- `logger` (Logger): Logger instance (default: `Rails.logger`)

**Returns:** Gamma URL (String) or nil if not completed


## Error Handling

The client raises `GammaClient::HTTP::GammaError` for API errors with appropriate status codes:

- 400: Bad Request
- 401: Unauthorized (Invalid API key)
- 404: Not Found
- 422: Generation failed
- 429: Rate limit exceeded
- 500: Internal server error
- 502: Bad gateway

## Configuration

The API key is configured in `config/initializers/gamma_api.rb` and loaded from Rails credentials under the `gamma` key.

## Testing

See `lib/gamma_client/example_usage.rb` for complete usage examples.
