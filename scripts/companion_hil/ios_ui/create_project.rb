# Generates a standalone UI test project around CompanionPhoneUITests.swift.
# Usage: ruby create_project.rb <new-output-dir>
# Env: ZSW_IOS_TEAM (signing team, needed to run on a phone),
#      ZSW_UITEST_BUNDLE_ID (runner bundle id, default dev.zswatch.companion.hil.acceptance).
require 'fileutils'
require 'xcodeproj'

root = File.expand_path(ARGV.fetch(0))
raise 'Use a new output directory' if File.exist?(root)

FileUtils.mkdir_p(root)
FileUtils.cp(File.join(__dir__, 'CompanionPhoneUITests.swift'), root)
project = Xcodeproj::Project.new(File.join(root, 'PhoneAcceptance.xcodeproj'))
target = project.new_target(:ui_test_bundle, 'PhoneAcceptance', :ios, '16.0')
target.add_file_references([project.main_group.new_file('CompanionPhoneUITests.swift')])
target.build_configurations.each do |configuration|
  configuration.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => ENV.fetch('ZSW_UITEST_BUNDLE_ID', 'dev.zswatch.companion.hil.acceptance'),
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SWIFT_VERSION' => '5.0',
    'DEVELOPMENT_TEAM' => ENV.fetch('ZSW_IOS_TEAM', ''),
    'CODE_SIGN_STYLE' => 'Automatic',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'TARGETED_DEVICE_FAMILY' => '1,2'
  })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target)
scheme.save_as(project.path, 'PhoneAcceptance', true)
puts "Created #{project.path}"
