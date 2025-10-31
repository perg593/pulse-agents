# frozen_string_literal: true

RSpec.shared_examples "color update" do
  it "rejects non-logged in users" do
    make_call(valid_color)
    assert_response 401
  end

  it "rejects possible answers from accounts that the current user does not belong to" do
    other_account_user = create(:user)
    sign_in other_account_user

    make_call(valid_color)

    it_fails(error_code: "404")
  end

  it "works for a logged in user" do
    sign_in user

    make_call(valid_color)

    expect(response).to have_http_status(:ok)
  end

  it "updates the record's report_color" do
    sign_in user

    new_color = valid_color
    patch :update_color, params: { id: record.id, color: new_color }

    record.reload
    expect(record.report_color).to eq(new_color)
  end

  it "fails when the new colour value is invalid" do
    sign_in user

    ["hello", ""].each do |invalid_color|
      make_call(invalid_color)
      it_fails
    end
  end

  def make_call(new_color)
    patch :update_color, params: { id: record.id, color: new_color }, xhr: true
  end

  def it_fails(error_code: "400")
    expect(response.code).to eq(error_code)

    record.reload
    expect(record.report_color).to eq(old_color)
  end
end
