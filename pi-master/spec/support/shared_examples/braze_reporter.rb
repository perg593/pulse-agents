# frozen_string_literal: true

RSpec.shared_examples "braze reporter" do
  let(:braze_url) { "https://rest.iad-03.braze.com/users/track" }
  let(:stubbed_headers) do
    {
      'Accept'=>'*/*',
      'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Content-Type'=>'application/x-www-form-urlencoded',
      'Host'=>'rest.iad-03.braze.com',
      'Authorization'=>"Bearer TEST_CREDENTIALS"
    }
  end
  let(:success_response) { {attributes_processed: 1, message: "success"}.to_json }

  let(:payload) do
    email_address = FFaker::Internet.email
    submission_udid = '00000000-0000-4000-f000-000000000001'
    favourite_player_names = ["Michael Jordan", "Shaquille O'Neil"]

    {
      attributes: [{
        external_id: email_address,
        submission_udid: submission_udid,
        pulse_favoritePlayer: favourite_player_names
      }]
    }
  end

  it "sends information to Braze" do
    encoded_payload = RestClient::Utils.encode_query_string(payload)

    stub = stub_request(:post, braze_url).
           with(body: encoded_payload, headers: stubbed_headers).
           to_return(status: 200, body: success_response, headers: {})

    subject.send_to_braze(payload)

    expect(stub).to have_been_requested
  end
end
