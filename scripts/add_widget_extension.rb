#!/usr/bin/env ruby
# Script to add the RunWalk Complications widget extension target to the Xcode project
# Uses the xcodeproj gem from CocoaPods

require 'xcodeproj'
require 'fileutils'

# Configuration
PROJECT_PATH = File.expand_path('../RunWalk.xcodeproj', __dir__)
WIDGET_NAME = 'RunWalk Complications'
WIDGET_BUNDLE_ID = 'com.vishutdhar.RunWalk.watchkitapp.complications'
WATCH_APP_TARGET_NAME = 'RunWalk Watch App'
WIDGET_DIR = File.expand_path('../RunWalk Complications', __dir__)

puts "Opening project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Check if target already exists
if project.targets.any? { |t| t.name == WIDGET_NAME }
  puts "ERROR: Target '#{WIDGET_NAME}' already exists. Aborting."
  exit 1
end

# Find the watch app target (to embed the extension)
watch_app_target = project.targets.find { |t| t.name == WATCH_APP_TARGET_NAME }
unless watch_app_target
  puts "ERROR: Could not find '#{WATCH_APP_TARGET_NAME}' target. Aborting."
  exit 1
end

puts "Found watch app target: #{watch_app_target.name}"

# Create the widget extension target
puts "Creating widget extension target: #{WIDGET_NAME}"
widget_target = project.new_target(
  :widget_extension,
  WIDGET_NAME,
  :watchos,
  '10.0'
)

# Set product name and bundle identifier
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = WIDGET_NAME
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE_ID
  config.build_settings['MARKETING_VERSION'] = '1.4'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  config.build_settings['DEVELOPMENT_TEAM'] = 'DABJS94K9F'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Config/RunWalkWidgetExtension.entitlements'
  config.build_settings['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'RunWalk'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['INFOPLIST_KEY_NSExtension'] = '$(EXTENSION_SAFE_API_ONLY)'
  # Remove any default info plist file reference
  config.build_settings.delete('INFOPLIST_FILE')
end

# Create or find the widget group in the project
widget_group = project.main_group.find_subpath(WIDGET_NAME, false)
if widget_group.nil?
  widget_group = project.main_group.new_group(WIDGET_NAME, WIDGET_DIR)
  puts "Created group: #{WIDGET_NAME}"
else
  puts "Found existing group: #{WIDGET_NAME}"
end

# Add source files to the target
source_files = [
  'RunWalkComplication.swift',
  'ComplicationTimelineProvider.swift',
]

views_group = widget_group.find_subpath('ComplicationViews', false)
if views_group.nil?
  views_group = widget_group.new_group('ComplicationViews', 'ComplicationViews')
end

view_files = [
  'ComplicationViews/CircularView.swift',
  'ComplicationViews/CornerView.swift',
  'ComplicationViews/RectangularView.swift',
  'ComplicationViews/InlineView.swift',
]

puts "Adding source files..."
source_files.each do |file|
  file_path = File.join(WIDGET_DIR, file)
  if File.exist?(file_path)
    file_ref = widget_group.new_file(file_path)
    widget_target.source_build_phase.add_file_reference(file_ref)
    puts "  Added: #{file}"
  else
    puts "  WARNING: File not found: #{file_path}"
  end
end

view_files.each do |file|
  file_path = File.join(WIDGET_DIR, file)
  if File.exist?(file_path)
    file_ref = views_group.new_file(file_path)
    widget_target.source_build_phase.add_file_reference(file_ref)
    puts "  Added: #{file}"
  else
    puts "  WARNING: File not found: #{file_path}"
  end
end

# Add Assets.xcassets
assets_path = File.join(WIDGET_DIR, 'Assets.xcassets')
if File.exist?(assets_path)
  assets_ref = widget_group.new_file(assets_path)
  widget_target.resources_build_phase.add_file_reference(assets_ref)
  puts "  Added: Assets.xcassets"
else
  puts "  WARNING: Assets.xcassets not found at #{assets_path}"
end

# Add the widget extension as an embedded extension in the watch app
puts "Embedding widget extension in watch app..."

# Find or create the "Embed App Extensions" build phase
embed_phase = watch_app_target.build_phases.find { |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
  phase.name == 'Embed App Extensions'
}

if embed_phase.nil?
  embed_phase = watch_app_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13'  # 13 = PlugIns folder for extensions
  puts "  Created 'Embed App Extensions' build phase"
end

# Add the widget product to the embed phase
widget_product_ref = widget_target.product_reference
embed_phase.add_file_reference(widget_product_ref)
puts "  Added widget extension to embed phase"

# Set attributes on the build file for proper signing
embed_phase.files.last.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Add target dependency
watch_app_target.add_dependency(widget_target)
puts "  Added target dependency"

# Save the project
puts "Saving project..."
project.save

puts ""
puts "SUCCESS! Widget extension target '#{WIDGET_NAME}' has been added."
puts ""
puts "Next steps:"
puts "1. Open RunWalk.xcodeproj in Xcode"
puts "2. Select the '#{WIDGET_NAME}' target"
puts "3. Go to Signing & Capabilities tab"
puts "4. Verify the App Group 'group.com.vishutdhar.RunWalk' is present"
puts "5. Build and test on watchOS Simulator"
