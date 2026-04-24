import Foundation

enum CLI {
    static func run(_ arguments: [String]) -> Int32 {
        let args = Array(arguments.dropFirst())

        if args.isEmpty || args.contains("--help") || args.contains("-h") {
            printHelp()
            return 0
        }

        if args.contains("--list") {
            printList()
            return 0
        }

        // Treat remaining tokens as library names.
        let repoRoot = BuildDriver.locateRepoRoot()
        let driver = BuildDriver(repoRoot: repoRoot)
        for name in args {
            guard let builder = LibraryRegistry.find(name) else {
                FileHandle.standardError.write(Data("error: unknown library: \(name)\n".utf8))
                FileHandle.standardError.write(Data("hint: run `build --list` to see available libraries.\n".utf8))
                return 1
            }
            let spec = builder.spec
            print(">> Building \(spec.name) \(spec.version) (\(spec.buildSystem.rawValue))")
            do {
                let out = try driver.build(library: builder, platforms: Platform.allCases)
                print("<< \(spec.name) → \(out.path)")
            } catch {
                FileHandle.standardError.write(Data("error: \(spec.name) build failed\n\(error)\n".utf8))
                return 1
            }
        }
        return 0
    }

    static func printHelp() {
        let help = """
        build — LemonBuild cross-compile driver

        USAGE:
            build [library ...]
            build --list
            build --help

        FLAGS:
            --list    List all registered libraries with their build systems.
            --help    Show this help message.

        Runs each listed library through fetch → configure → compile → install → xcframework
        assembly for every slice in Platform.allCases. Products land in Frameworks/.
        """
        print(help)
    }

    static func printList() {
        let libs = LibraryRegistry.libraries
        if libs.isEmpty {
            print("No libraries registered.")
            return
        }
        let nameWidth = max(4, libs.map(\.name.count).max() ?? 4)
        let versionWidth = max(7, libs.map(\.version.count).max() ?? 7)
        print("\("NAME".padding(toLength: nameWidth, withPad: " ", startingAt: 0))  " +
              "\("VERSION".padding(toLength: versionWidth, withPad: " ", startingAt: 0))  BUILDSYSTEM")
        for lib in libs {
            let name = lib.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            let version = lib.version.padding(toLength: versionWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(version)  \(lib.buildSystem.rawValue)")
        }
    }
}

exit(CLI.run(CommandLine.arguments))
