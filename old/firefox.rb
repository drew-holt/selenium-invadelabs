# frozen_string_literal: true

# Drew Holt <drew@invadelabs.com>
# https://github.com/invadelabs/selenium-invadelabs
# Sn up selenium firefox container, take a screenshot

require 'selenium-webdriver'
require 'rspec/expectations'

include RSpec::Matchers

def setup
  @driver = Selenium::WebDriver.for(
    :remote,
    url: 'http://localhost:4445/wd/hub',
    desired_capabilities: :firefox
  ) # or chrome or whatever
end

def teardown
  @driver.quit
end

def run
  setup
  yield
  teardown
end

run do
  @driver.get('http://invadelabs.com/')
  expect(@driver.title).to eql 'invadelabs.com'

  @driver.find_element(:css, 'i.icon-reorder').click
  # expect(@driver.find_element(:link, 'Menu').text).to eql 'Menu'

  # @driver.find_element(:link, "Contact Me").click
  # expect(@driver.find_element(:link, 'Contact Me').text).to eql 'Contact Me'

  t = Time.now
  t_proc = t.strftime '%Y.%m.%d.%H.%M.%S%z'

  @driver.save_screenshot("firefox_invadelabs.com.#{t_proc}.png")
end
