require 'selenium-webdriver'
require 'rspec/expectations'
require 'sendgrid-ruby'
require 'image_optim'
require 'slack-ruby-client'

include SendGrid

include RSpec::Matchers

BROWSERS = { chrome: 'http://localhost:4444/wd/hub',
             firefox: 'http://localhost:4445/wd/hub' }.freeze

def setup(browser_name, url)
  caps = Selenium::WebDriver::Remote::Capabilities.send(browser_name.to_sym)

  @driver = Selenium::WebDriver.for(
    :remote,
    url: url.to_s,
    desired_capabilities: caps
  )
end

def teardown
  @driver.quit
end

############################################
# Compress Image Method
def compressimage(filename)
  image_optim = ImageOptim.new(skip_missing_workers: true,
                               verbose: false,
                               optipng: { level: 6 },
                               pngcrush: false,
                               jpegtran: false,
                               pngout: false,
                               advpng: false,
                               pngquant: false,
                               jhead: false,
                               jpegoptim: false,
                               gifsicle: false,
                               svgo: false)
  image_optim.optimize_image!(filename)
  puts "Compressing #{filename}"
end

# Sendmail via Sendgrid Method
def sendmail(filename)
  # Email the screenshot via sendgrid
  mail = Mail.new
  mail.from = Email.new(email: 'testing@invadelabs.com')
  mail.subject = "invadelabs.com #{filename}"

  personalization2 = Personalization.new
  # personalization2.add_to(Email.new(email: 'drewderivative@gmail.com', name: 'Drew'))
  personalization2.add_to(Email.new(email: 'drewderivative@gmail.com'))
  # personalization2.subject = 'Hello World from the Personalized SendGrid Ruby Library'
  mail.add_personalization(personalization2)

  # mail.add_content(Content.new(type: 'text/plain', value: 'some text here'))
  mail.add_content(Content.new(type: 'text/html', value: "<html><body>invadelabs.com #{filename}</body></html>"))

  attachment = Attachment.new
  attachment.content = Base64.strict_encode64(File.open(filename, 'rb').read)
  attachment.type = 'image/png'
  attachment.filename = filename
  attachment.disposition = 'attachment'
  attachment.content_id = 'Screenshot'
  mail.add_attachment(attachment)

  # leaving this out due to base64 encoding adding 600k to output
  # puts JSON.pretty_generate(mail.to_json)
  # puts mail.to_json

  sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'], host: 'https://api.sendgrid.com')
  response = sg.client.mail._('send').post(request_body: mail.to_json)
  puts response.status_code
  puts response.body
  puts response.headers
  puts "Sending email with #{filename}"
end

# Slack Method
def slack(filename)
  Slack.configure do |config|
    config.token = ENV['SLACK_API_TOKEN']
    raise 'Missing ENV[SLACK_API_TOKEN]!' unless config.token
  end

  client = Slack::Web::Client.new

  client.auth_test

  # client.chat_postMessage(channel: '#general', text: 'Hello World', as_user: true)

  client.files_upload(
    channels: '#selenium-ci',
    as_user: true,
    file: Faraday::UploadIO.new(filename, 'image/png'),
    title: filename,
    filename: filename,
    initial_comment: "Selenium: #{filename}"
  )
  puts "Slacking #{filename}"
end

############################################
def run
  BROWSERS.each_pair do |browser_name, url|
    setup(browser_name, url)
    yield
    teardown
  end
end

run do
  puts "Starting #{@driver.browser} webdriver"
  @driver.get('http://invadelabs.com/')
  expect(@driver.title).to eql 'invadelabs.com'

  @driver.find_element(:css, 'i.icon-reorder').click
  # expect(@driver.find_element(:link, 'Menu').text).to eql 'Menu'

  # @driver.find_element(:link, "Contact Me").click
  # expect(@driver.find_element(:link, 'Contact Me').text).to eql 'Contact Me'

  t = Time.now
  t_proc = t.strftime '%Y.%m.%d.%H.%M.%S%z'

  screenshot_name = "#{@driver.browser}_invadelabs.com.#{t_proc}.png"
  @driver.save_screenshot(screenshot_name)

  compressimage(screenshot_name)

  # sendmail(screenshot_name)

  slack(screenshot_name)
end