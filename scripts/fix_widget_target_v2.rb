#!/usr/bin/env ruby
# Script to fix the widget extension target for watchOS

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../RunWalk.xcodeproj', __dir__)
WIDGET_NAME = 'RunWalk Complications'

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find the widget target
widget_target = project.targets.find { |t| t.name == WIDGET_NAME }
unless widget_target
  puts "ERROR: Could not find '#{WIDGET_NAME}' target. Aborting."
  exit 1
end

puts "Found widget target: #{widget_target.name}"

# Try the extensionkit-extension product type (used by watchOS 10+ widgets)
# This is the modern product type for WidgetKit extensions on watchOS
WIDGET_PRODUCT_TYPE = 'com.apple.product-type.extensionkit-extension'
widget_target.product_type = WIDGET_PRODUCT_TYPE
puts "Set product type to: #{WIDGET_PRODUCT_TYPE}"

# Fix the product reference file type
product_ref = widget_target.product_reference
if product_ref
  product_ref.explicit_file_type = 'wrapper.extensionkit-extension'
  product_ref.include_in_index = '0'
  product_ref.path = "#{WIDGET_NAME}.appex"
  puts "Fixed product reference file type and path"
end

# Configure build settings for watchOS ExtensionKit extension
widget_target.build_configurations.each do |config|
  settings = config.build_settings

  # Core watchOS settings
  settings['TARGETED_DEVICE_FAMILY'] = '4'  # 4 = watchOS
  settings['SDKROOT'] = 'watchos'
  settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'

  # Extension settings
  settings['WRAPPER_EXTENSION'] = 'appex'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'

  # Info.plist generation for ExtensionKit
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'RunWalk'
  settings['INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier'] = 'com.apple.widgetkit-extension'

  # Code signing
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['DEVELOPMENT_TEAM'] = 'DABJS94K9F'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'Config/RunWalkWidgetExtension.entitlements'

  # Swift settings
  settings['SWIFT_VERSION'] = '6.0'
  settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'

  # Asset catalog
  settings['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
  settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'

  # Bundle identifier
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.vishutdhar.RunWalk.watchkitapp.complications'
  settings['PRODUCT_NAME'] = '$(TARGET_NAME)'

  # Skip install for extensions
  settings['SKIP_INSTALL'] = 'YES'

  # Linker settings
  settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'

  puts "  Configured #{config.name} settings"
end

puts "Saving project..."
project.save

puts ""
puts "SUCCESS! Widget target has been fixed with ExtensionKit product type."
puts "Try building again."
