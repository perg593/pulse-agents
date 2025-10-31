# frozen_string_literal: true

# Requires two variables:
#   - full_access_user
#   - reporting_only_user
#
# An experiment in making authorization tests for controllers less repetitive
RSpec.shared_examples "survey update experiment" do
  def make_the_call(_user, _survey)
    raise NotImplementedError, "You must implement 'make_the_call' to use 'survey update experiment'"
  end

  def it_works(_survey)
    raise NotImplementedError, "You must implement 'it_works' to use 'survey update experiment'"
  end

  def it_does_not_work(_survey)
    raise NotImplementedError, "You must implement 'it_does_not_work' to use 'survey update experiment'"
  end

  it "works for a full access user" do
    user = full_access_user
    survey = create(:survey, account: user.account)

    make_the_call(user, survey)

    it_works(survey)
  end

  it "does not work for a reporting-only user" do
    user = reporting_only_user
    survey = create(:survey, account: user.account)

    make_the_call(user, survey)

    it_does_not_work(survey)
  end
end
