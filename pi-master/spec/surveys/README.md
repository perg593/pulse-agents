# Survey widget specs

These tests are "end-to-end" in that they prove that changes to the database are reflected in the survey widget. They are the most complete (and slowest and complicated) tests.

## General flow

- Start a rails server to run the app
- Modify the database
- Start selenium webdriver and point it to a file which loads the survey JS
- Wait for the survey widget to load
- Interact with the survey widget
- Make assertions

## Best practices

We recommend batching your test cases as much as possible, even if it looks gross, since these tests are somewhat slow. See the following contrived example.

```ruby
# bad
describe "element attributes" do
  { subject } { element.attributes }

  it { is_expected.to not_be nil }
  it { is_expected.to include "width" }
  it { is_expected.to include "height" }
end

# good
describe "element attributes" do
  let(:attributes) { element.attributes }

  it "has the expected attributes" do
    expect(attributes).not_to be_nil
    expect(attributes.include("width")).to be true
    expect(attributes.include("height")).to be true
  end
end
```

Try to initialize the webdriver as late as possible, since you can't modify the db afterwards.

## Gotchas

If you modify the database after loading the driver then your changes will not be visible in the widget.
i.e. Your account, survey, questions, etc. must be configured before the driver loads the file which will host the survey.

Sometimes you need to wait a little for something to happen. If an element does not appear, try waiting
