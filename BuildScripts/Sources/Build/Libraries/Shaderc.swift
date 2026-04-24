import Foundation

struct ShadercBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "shaderc",
        version: "v2025.5",
        source: .git(url: "https://github.com/google/shaderc.git", ref: "v2025.5"),
        buildSystem: .cmake,
        dependencies: [],
        xcframeworkName: "Shaderc",
        moduleName: "Shaderc"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        // shaderc pulls SPIRV-Tools / glslang / SPIRV-Headers / abseil / effcee /
        // googletest / re2 via Chromium-style `DEPS` + `utils/git-sync-deps`.
        // Idempotent: if third_party is already populated, the script is a no-op.
        try Shell.run(
            "python3",
            args: ["utils/git-sync-deps"],
            currentDirectory: context.sourceDir
        )

        let cmake = CMakeBuilder(
            toolchain: context.toolchain,
            sourceDir: context.sourceDir,
            buildDir: context.buildDir,
            installDir: context.installDir,
            extraConfigureArgs: [
                "-DSHADERC_SKIP_TESTS=ON",
                "-DSHADERC_SKIP_EXAMPLES=ON",
                "-DSHADERC_SKIP_COPYRIGHT_CHECK=ON",
                "-DSHADERC_ENABLE_SHARED_CRT=OFF",
                "-DSPIRV_SKIP_TESTS=ON",
                "-DSPIRV_SKIP_EXECUTABLES=ON",
                "-DSPIRV_WERROR=OFF",
                "-DBUILD_TESTING=OFF",
                "-DENABLE_GLSLANG_BINARIES=OFF",
                "-DENABLE_OPT=ON",
                "-DENABLE_CTEST=OFF",
                "-DENABLE_SPVREMAPPER=OFF",
                "-DSKIP_GLSLANG_INSTALL=OFF"
            ],
            extraEnv: context.pkgConfigEnv
        )
        try cmake.configure()
        try cmake.build()
        try cmake.install()

        // Upstream installs `libshaderc_combined.a` only when explicitly asked;
        // default builds ship `libshaderc.a` which leaves SPIRV-Tools/glslang as
        // undefined externs. libplacebo expects the combined form, so rebuild
        // it here out of the per-component archives produced by the cmake build.
        let staticLib = context.installDir.appendingPathComponent("lib/libshaderc_combined.a")
        if !FileManager.default.fileExists(atPath: staticLib.path) {
            try assembleCombinedArchive(buildDir: context.buildDir, output: staticLib)
        }

        try stripDylibsAndRewirePkgConfig(installDir: context.installDir)

        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            umbrellaHeader: "shaderc/shaderc.h"
        )
        return InstallArtifact(staticLibrary: staticLib, headersRoot: stage)
    }

    /// Build `libshaderc_combined.a` by merging every component's static archive
    /// produced under the CMake build tree. Mirrors upstream's
    /// `shaderc_combined_genfile` target but without requiring CMake to exec
    /// host-native post-install scripts.
    private func assembleCombinedArchive(buildDir: URL, output: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: output)

        // Candidate component archives. Relative paths inside the build tree.
        let candidates = [
            "libshaderc/libshaderc.a",
            "libshaderc_util/libshaderc_util.a",
            "third_party/glslang/glslang/libglslang.a",
            "third_party/glslang/glslang/libMachineIndependent.a",
            "third_party/glslang/glslang/libGenericCodeGen.a",
            "third_party/glslang/glslang/OSDependent/Unix/libOSDependent.a",
            "third_party/glslang/SPIRV/libSPIRV.a",
            "third_party/spirv-tools/source/libSPIRV-Tools.a",
            "third_party/spirv-tools/source/opt/libSPIRV-Tools-opt.a"
        ]
        var archives: [String] = []
        for rel in candidates {
            let p = buildDir.appendingPathComponent(rel)
            if fm.fileExists(atPath: p.path) {
                archives.append(p.path)
            }
        }
        guard !archives.isEmpty else {
            throw NSError(
                domain: "LemonBuild.Shaderc",
                code: 20,
                userInfo: [NSLocalizedDescriptionKey: "no component archives found under \(buildDir.path)"]
            )
        }
        var args: [String] = ["-static", "-o", output.path]
        args.append(contentsOf: archives)
        try Shell.run("libtool", args: args)
    }

    /// Upstream shaderc installs both `libshaderc_shared.dylib` (default
    /// `shaderc.pc` target) and `libshaderc_combined.a`. For static iOS linking
    /// we want the combined archive; rewrite `shaderc.pc` so
    /// `dependency('shaderc')` in libplacebo resolves to it, and drop the
    /// dylibs so the linker can't pick them up by accident.
    private func stripDylibsAndRewirePkgConfig(installDir: URL) throws {
        let fm = FileManager.default
        let libDir = installDir.appendingPathComponent("lib")
        if let entries = try? fm.contentsOfDirectory(atPath: libDir.path) {
            for entry in entries where entry.hasSuffix(".dylib") {
                try? fm.removeItem(at: libDir.appendingPathComponent(entry))
            }
        }
        let pcFile = libDir.appendingPathComponent("pkgconfig/shaderc.pc")
        if fm.fileExists(atPath: pcFile.path) {
            let content = try String(contentsOf: pcFile, encoding: .utf8)
            let rewritten = content.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
                if line.hasPrefix("Libs:") {
                    return "Libs: -L${libdir} -lshaderc_combined"
                }
                return String(line)
            }.joined(separator: "\n")
            try rewritten.write(to: pcFile, atomically: true, encoding: .utf8)
        }
    }
}
