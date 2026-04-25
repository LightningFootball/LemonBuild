#!/usr/bin/env ruby
# Wire LemonBuild as a local Swift Package dependency of the Lemon Xcode
# project. Idempotent: re-running with the same args is a no-op.
#
# Usage:
#   ./scripts/wire-lemon-spm.rb <Lemon.xcodeproj> <relative-path-to-LemonBuild>
#
# Example (run from anywhere, paths can be relative to wherever you invoke):
#   ./scripts/wire-lemon-spm.rb ~/workspace/Lemon/Lemon.xcodeproj ../LemonBuild

require 'xcodeproj'

project_path = ARGV[0] or abort("usage: #{$0} <Lemon.xcodeproj> <relative-path-to-LemonBuild>")
package_path = ARGV[1] or abort("usage: #{$0} <Lemon.xcodeproj> <relative-path-to-LemonBuild>")

# All the Swift modules that LemonBuild's Package.swift exposes via .library
# products. The host app (Lemon) needs each one as a SPM product dependency
# so that `import <Module>` resolves at compile time and the static
# xcframework gets linked at link time.
PRODUCTS = %w[
  Libmpv
  FFmpeg
  Libass
  Libplacebo
  MoltenVK
  Shaderc
  Dav1d
  FreeType
  Fribidi
  Harfbuzz
  Uchardet
]

# System-side libraries / frameworks libmpv's transitive deps need:
#   * `iconv` — libass charset conversion (already in iOS sysroot)
#   * `c++`   — shaderc / libplacebo C++ bits
#   * AudioToolbox / AVFoundation / CoreMedia / CoreVideo / VideoToolbox /
#     Metal / QuartzCore / IOSurface — VideoToolbox decode + MoltenVK render
#   * Foundation / CoreFoundation / Security / CoreGraphics — pulled by
#     various MoltenVK / FFmpeg paths
SYSTEM_LIBRARIES = %w[libiconv.tbd libc++.tbd]
SYSTEM_FRAMEWORKS = %w[
  AudioToolbox AVFoundation CoreMedia CoreVideo VideoToolbox
  Metal QuartzCore IOSurface
  Foundation CoreFoundation CoreGraphics Security
]

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t|
  t.is_a?(Xcodeproj::Project::Object::PBXNativeTarget) &&
    t.product_type == "com.apple.product-type.application"
} or abort("no Application target found in #{project_path}")
puts "[wire] target: #{target.name}"

# 1. Local SPM package reference on the project.
existing_pkg_refs = project.root_object.package_references.select { |r|
  r.is_a?(Xcodeproj::Project::Object::XCLocalSwiftPackageReference) &&
    r.relative_path == package_path
}
local_pkg = existing_pkg_refs.first
unless local_pkg
  local_pkg = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  local_pkg.relative_path = package_path
  project.root_object.package_references << local_pkg
  puts "[wire] added XCLocalSwiftPackageReference -> #{package_path}"
else
  puts "[wire] local package ref already present"
end

# 2. Product dependencies on the target's Frameworks build phase.
phase = target.frameworks_build_phase
existing_deps = target.package_product_dependencies.map(&:product_name)

PRODUCTS.each do |product_name|
  if existing_deps.include?(product_name)
    puts "[wire] product #{product_name}: already wired"
    next
  end
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = local_pkg
  dep.product_name = product_name
  target.package_product_dependencies << dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  phase.files << build_file
  puts "[wire] linked #{product_name}"
end

# 3. System libraries / frameworks the static archives depend on at link time.
# Use a generic helper: skip if a same-named ref already exists in the phase.
existing_sys_files = phase.files.map { |bf|
  bf.file_ref&.path
}.compact

(SYSTEM_LIBRARIES + SYSTEM_FRAMEWORKS.map { |f| "System/Library/Frameworks/#{f}.framework" }).each do |lib_path|
  next if existing_sys_files.include?(lib_path)
  ref = project.frameworks_group.new_file(lib_path, :sdk_root)
  build_file = phase.add_file_reference(ref)
  puts "[wire] linked system #{lib_path}"
end

project.save
puts "[wire] done -> #{project_path}"
