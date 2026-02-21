require "cgi"
require "json"

# Helpers for asserting against Inertia.js responses in ActionDispatch::IntegrationTest.
#
# Inertia embeds page data as JSON in the `data-page` attribute of the root `<div id="app">`.
# Rails HTML-escapes the attribute value, so double-quotes appear as `&quot;`.
# These helpers decode and parse that payload so tests can make clean assertions without
# relying on `assert_select` or inspecting raw HTML.
#
# Usage — include automatically for all integration tests via test_helper.rb:
#
#   ActiveSupport.on_load(:action_dispatch_integration_test) do
#     include InertiaTestHelper
#   end
#
# Then in any ActionDispatch::IntegrationTest:
#
#   get new_password_path
#   assert_inertia_component "Auth/ForgotPassword"
#   assert_inertia_props "currentUser" => nil, "errors" => {}
#
#   follow_redirect!
#   assert_inertia_flash "notice" => "Password has been reset."
#
module InertiaTestHelper
  # Returns the full parsed Inertia page object, e.g.:
  #   {
  #     "component" => "Auth/ForgotPassword",
  #     "props"     => { "errors" => {}, "flash" => {}, "currentUser" => nil },
  #     "url"       => "/passwords/new",
  #     ...
  #   }
  # Returns an empty hash when the response body contains no Inertia payload.
  def inertia_page
    match = response.body.match(/data-page="([^"]*)"/)
    return {} unless match

    JSON.parse(CGI.unescapeHTML(match[1]))
  end

  # Returns the rendered Inertia component name, e.g. "Auth/ForgotPassword".
  def inertia_component
    inertia_page["component"]
  end

  # Returns the merged props hash (shared + component props) as parsed from JSON.
  # All keys are strings because the data round-trips through JSON.
  def inertia_props
    inertia_page["props"] || {}
  end

  # Returns the flash sub-hash from the Inertia props.
  # InertiaController shares flash via `inertia_share flash: -> { flash.to_hash }`,
  # so flash data lives at props["flash"].
  def inertia_flash
    inertia_props["flash"] || {}
  end

  # ---------------------------------------------------------------------------
  # Assertions
  # ---------------------------------------------------------------------------

  # Assert that the response renders the given Inertia component.
  #
  #   assert_inertia_component "Auth/ForgotPassword"
  def assert_inertia_component(expected, message = nil)
    actual = inertia_component
    assert_equal(
      expected,
      actual,
      message || "Expected Inertia component to be #{expected.inspect}, got #{actual.inspect}"
    )
  end

  # Assert that the Inertia props contain every key/value pair in +expected+.
  # This is a partial/subset match — extra props in the response are ignored.
  # Both symbol and string keys are accepted in +expected+; they are normalised
  # to strings before comparison (matching what JSON serialisation produces).
  #
  #   assert_inertia_props "currentUser" => nil, "errors" => {}
  #   assert_inertia_props currentUser: nil, errors: {}  # symbol keys also work
  def assert_inertia_props(expected)
    actual = inertia_props
    # Normalise expected to string keys so callers can use symbol or string keys.
    normalised = JSON.parse(expected.to_json)
    normalised.each do |key, value|
      if value.nil?
        assert_nil(
          actual[key],
          "Expected Inertia prop #{key.inspect} to be nil, " \
          "but got #{actual[key].inspect}.\nAll props: #{actual.inspect}"
        )
      else
        assert_equal(
          value,
          actual[key],
          "Expected Inertia prop #{key.inspect} to be #{value.inspect}, " \
          "but got #{actual[key].inspect}.\nAll props: #{actual.inspect}"
        )
      end
    end
  end

  # Assert that the Inertia flash (props["flash"]) contains every key/value pair
  # in +expected+. This is a subset match.
  # Keys can be symbols or strings; they are normalised to strings.
  #
  #   assert_inertia_flash "notice" => "Password has been reset."
  #   assert_inertia_flash notice: "Password has been reset."  # symbol keys also work
  def assert_inertia_flash(expected)
    actual = inertia_flash
    normalised = JSON.parse(expected.to_json)
    normalised.each do |key, value|
      assert_equal(
        value,
        actual[key],
        "Expected Inertia flash[#{key.inspect}] to be #{value.inspect}, " \
        "but got #{actual[key].inspect}.\nFlash: #{actual.inspect}"
      )
    end
  end

  # Assert that the response body contains a valid Inertia payload at all.
  def assert_inertia_response
    assert(
      inertia_page.key?("component"),
      "Expected an Inertia response but found no data-page payload in the response body."
    )
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include InertiaTestHelper
end
