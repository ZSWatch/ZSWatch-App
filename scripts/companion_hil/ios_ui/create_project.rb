require 'fileutils'
require 'xcodeproj'

root = File.expand_path(ARGV.fetch(0))
team = ENV.fetch('ZSW_IOS_TEAM')
raise 'Use a new output directory' if File.exist?(root)
FileUtils.mkdir_p(root)
FileUtils.cp(File.join(__dir__, 'CompanionPhoneUITests.swift'), root)
project = Xcodeproj::Project.new(File.join(root, 'PhoneAcceptance.xcodeproj'))
target = project.new_target(:ui_test_bundle, 'PhoneAcceptance', :ios, '14.0')
target.add_file_references([project.main_group.new_file('CompanionPhoneUITests.swift')])
target.build_configurations.each do |configuration|
  configuration.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'dev.zswatch.companion.hil.acceptance',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SWIFT_VERSION' => '5.0',
    'DEVELOPMENT_TEAM' => team,
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
