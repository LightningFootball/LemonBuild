import Foundation

struct FFmpegBuilder: LibraryBuilder {
    let spec = LibrarySpec(
        name: "ffmpeg",
        version: "n7.1",
        source: .git(url: "https://github.com/FFmpeg/FFmpeg.git", ref: "n7.1"),
        buildSystem: .autotools,
        dependencies: ["dav1d"],
        xcframeworkName: "FFmpeg",
        moduleName: "FFmpeg"
    )

    func buildSlice(context: BuildContext) throws -> InstallArtifact {
        try configureFFmpeg(context: context)
        try Shell.run(
            "make",
            args: ["-j\(ProcessInfo.processInfo.activeProcessorCount)"],
            currentDirectory: context.buildDir
        )
        try Shell.run(
            "make", args: ["install"],
            currentDirectory: context.buildDir
        )

        // Merge libav*.a into a single combined archive so the xcframework
        // exposes one `libffmpeg.a` per slice — simpler consumption than the
        // 7-way split upstream emits.
        let merged = context.installDir.appendingPathComponent("lib/libffmpeg.a")
        try mergeLibraries(installDir: context.installDir, output: merged)

        // libplacebo's `<vulkan/...>` cross-module ref problem doesn't affect
        // FFmpeg, but self-refs like `<libavcodec/avcodec.h>` do. Stage headers
        // and rewrite self-includes to quoted relative paths.
        let stage = context.installDir.appendingPathComponent("Headers")
        try HeadersStager.stage(
            source: context.installDir.appendingPathComponent("include"),
            stageRoot: stage,
            moduleName: spec.moduleName,
            style: .umbrellaDir()
        )
        let moduleContent = stage.appendingPathComponent(spec.moduleName)
        try IncludeRewriter.rewriteSelfIncludes(
            in: moduleContent,
            prefixes: ["libavcodec", "libavformat", "libavutil", "libswresample",
                       "libswscale", "libavfilter", "libavdevice", "libpostproc"],
            replacement: { prefix, name, depth in
                String(repeating: "../", count: depth) + "\(prefix)/\(name)"
            },
            recursive: true
        )
        // Drop hwaccel headers for platforms that don't ship on iOS — these
        // pull in `<d3d11.h>` / `<windows.h>` / `<vdpau/...>` / `<jni.h>` and
        // fail umbrella-dir module compilation. The corresponding hwaccels
        // were already disabled at FFmpeg configure time, so the headers are
        // dead surface in the install.
        try dropNonAppleHwaccelHeaders(in: moduleContent)
        return InstallArtifact(staticLibrary: merged, headersRoot: stage)
    }

    private func configureFFmpeg(context: BuildContext) throws {
        let tc = context.toolchain
        try? FileManager.default.removeItem(at: context.buildDir)
        try FileManager.default.createDirectory(at: context.buildDir, withIntermediateDirectories: true)

        // FFmpeg's own configure (not GNU autotools): uses its own flag
        // vocabulary — no `--host`, `--enable-static/--disable-shared` instead
        // of `--enable-static=yes --disable-shared`, etc.
        var args: [String] = []
        args.append("--prefix=\(context.installDir.path)")
        args.append("--enable-cross-compile")
        args.append("--target-os=darwin")
        args.append("--arch=arm64")
        args.append("--sysroot=\(tc.sdkPath)")
        args.append("--cc=\(tc.clangPath)")
        args.append("--cxx=\(tc.clangxxPath)")
        args.append("--ar=\(tc.arPath)")
        args.append("--ranlib=\(tc.ranlibPath)")
        args.append("--strip=\(tc.stripPath)")
        args.append("--enable-static")
        args.append("--disable-shared")

        // LGPL v3-or-later; no GPL components.
        args.append("--enable-version3")
        args.append("--disable-gpl")
        args.append("--disable-nonfree")

        // Player-side: we demux / decode, not encode / mux.
        args.append("--disable-encoders")
        args.append("--disable-muxers")
        args.append("--disable-programs")
        args.append("--disable-doc")
        args.append("--disable-debug")
        args.append("--disable-htmlpages")
        args.append("--disable-manpages")
        args.append("--disable-podpages")
        args.append("--disable-txtpages")
        args.append("--disable-ffmpeg")
        args.append("--disable-ffplay")
        args.append("--disable-ffprobe")

        // iOS hardware decoding via VideoToolbox; keep Metal-free (gpu-next +
        // MoltenVK handles rendering separately). Player doesn't need
        // capture/device I/O — libavdevice's audiotoolbox.m references
        // macOS-only `kAudioDevicePropertyScopeInput` and won't compile on iOS.
        args.append("--enable-videotoolbox")
        args.append("--disable-avdevice")
        args.append("--disable-indevs")
        args.append("--disable-outdevs")

        // Wire up dav1d we built in Stage 2 for AV1 software fallback.
        args.append("--enable-libdav1d")

        // Target-specific clang flags (min iOS version, target triple).
        let extraCFlags = tc.cFlags.joined(separator: " ")
        let extraLDFlags = tc.ldFlags.joined(separator: " ")
        args.append("--extra-cflags=\(extraCFlags)")
        args.append("--extra-ldflags=\(extraLDFlags)")

        let configure = context.sourceDir.appendingPathComponent("configure")
        try Shell.run(
            configure.path,
            args: args,
            env: context.pkgConfigEnv,
            currentDirectory: context.buildDir
        )
    }

    private func dropNonAppleHwaccelHeaders(in moduleContent: URL) throws {
        let fm = FileManager.default
        let drops: [String: [String]] = [
            "libavcodec": [
                "d3d11va.h", "dxva2.h", "vdpau.h", "qsv.h",
                "jni.h", "mediacodec.h"
            ],
            "libavutil": [
                "hwcontext_d3d11va.h", "hwcontext_d3d12va.h",
                "hwcontext_dxva2.h", "hwcontext_qsv.h",
                "hwcontext_vaapi.h", "hwcontext_vdpau.h",
                "hwcontext_drm.h", "hwcontext_mediacodec.h",
                "hwcontext_amf.h", "hwcontext_opencl.h",
                "hwcontext_vulkan.h", "hwcontext_cuda.h"
            ]
        ]
        for (subdir, files) in drops {
            for f in files {
                try? fm.removeItem(at: moduleContent.appendingPathComponent("\(subdir)/\(f)"))
            }
        }
    }

    private func mergeLibraries(installDir: URL, output: URL) throws {
        let fm = FileManager.default
        let libDir = installDir.appendingPathComponent("lib")
        let libs = ["libavcodec.a", "libavformat.a", "libavfilter.a",
                    "libavutil.a", "libswresample.a", "libswscale.a"]
        let paths = libs
            .map { libDir.appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0.path) }
            .map { $0.path }
        try? fm.removeItem(at: output)
        try Shell.run("libtool", args: ["-static", "-o", output.path] + paths)
    }
}
