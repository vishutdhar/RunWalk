#!/usr/bin/env ruby
# Script to fix the widget extension target's productType

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
puts "Current product type: #{widget_target.product_type}"

# Set the correct product type for widget extension
WIDGET_PRODUCT_TYPE = 'com.apple.product-type.app-extension.widget-extension'
widget_target.product_type = WIDGET_PRODUCT_TYPE
puts "Set product type to: #{WIDGET_PRODUCT_TYPE}"

# Fix the product reference file type
product_ref = widget_target.product_reference
if product_ref
  product_ref.explicit_file_type = 'wrapper.app-extension'
  product_ref.include_in_index = '0'
  puts "Fixed product reference file type"
end

# Make sure build settings are correct
widget_target.build_configurations.each do |config|
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'  # 4 = watchOS
  config.build_settings['SDKROOT'] = 'watchos'
  config.build_settings['WRAPPER_EXTENSION'] = 'appex'
end

puts "Saving project..."
project.save

puts ""
puts "SUCCESS! Widget target has been fixed."
puts "Try building again."
