import Foundation

/// Renders a [meson cross-compilation file](https://mesonbuild.com/Cross-compilation.html)
/// describing one iOS slice.
struct MesonCrossFile {
    let toolchain: Toolchain

    func render() -> String {
        let tc = toolchain
        var lines: [String] = []

        lines.append("[binaries]")
        lines.append("c = '\(tc.clangPath)'")
        lines.append("cpp = '\(tc.clangxxPath)'")
        lines.append("objc = '\(tc.clangPath)'")
        lines.append("objcpp = '\(tc.clangxxPath)'")
        lines.append("ar = '\(tc.arPath)'")
        lines.append("ranlib = '\(tc.ranlibPath)'")
        lines.append("strip = '\(tc.stripPath)'")
        lines.append("pkg-config = 'pkg-config'")
        lines.append("")

        lines.append("[host_machine]")
        lines.append("system = 'darwin'")
        lines.append("subsystem = '\(tc.platform.mesonSubsystem)'")
        lines.append("cpu_family = '\(tc.arch.mesonCPUFamily)'")
        lines.append("cpu = '\(tc.arch.mesonCPU)'")
        lines.append("endian = 'little'")
        lines.append("")

        lines.append("[built-in options]")
        lines.append("c_args = \(listLiteral(tc.cFlags))")
        lines.append("cpp_args = \(listLiteral(tc.cFlags))")
        lines.append("objc_args = \(listLiteral(tc.cFlags))")
        lines.append("objcpp_args = \(listLiteral(tc.cFlags))")
        lines.append("c_link_args = \(listLiteral(tc.ldFlags))")
        lines.append("cpp_link_args = \(listLiteral(tc.ldFlags))")
        lines.append("objc_link_args = \(listLiteral(tc.ldFlags))")
        lines.append("objcpp_link_args = \(listLiteral(tc.ldFlags))")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private func listLiteral(_ items: [String]) -> String {
        "[" + items.map { "'\($0)'" }.joined(separator: ", ") + "]"
    }
}
