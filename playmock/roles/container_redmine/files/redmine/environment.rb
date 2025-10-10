# frozen_string_literal: true

# Load the Rails application
require File.expand_path('../application', __FILE__)

# Make sure there's no plugin in vendor/plugin before starting
vendor_plugins_dir = File.join(Rails.root, "vendor", "plugins")
if Dir.glob(File.join(vendor_plugins_dir, "*")).any?
  $stderr.puts "Plugins in vendor/plugins (#{vendor_plugins_dir}) are no longer allowed. " \
    "Please, put your Redmine plugins in the `plugins` directory at the root of your " \
    "Redmine directory (#{File.join(Rails.root, "plugins")})"
  exit 1
end

# /ticket で運用する設定 (Initialize前設定)
RedmineApp::Application.routes.default_scope = "/ticket"

# Initialize the Rails application
Rails.application.initialize!

# /ticket で運用する設定 (Initialize後設定)
Redmine::Utils::relative_url_root = "/ticket"
ActionController::Base.relative_url_root = "/ticket"
