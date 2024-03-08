//
//  RswiftGenerateInternalResources.swift
//  
//
//  Created by Tom Lokhorst on 2022-10-19.
//

import Foundation
import PackagePlugin

@main
struct RswiftGenerateInternalResources: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }

        let outputDirectoryPath = context.pluginWorkDirectory
            .appending(subpath: target.name)

        try FileManager.default.createDirectory(atPath: outputDirectoryPath.string, withIntermediateDirectories: true)

        let rswiftPath = outputDirectoryPath.appending(subpath: "R.generated.swift")

        let sourceFiles = target.sourceFiles
            .filter { $0.type == .resource || $0.type == .unknown }
            .map(\.path.string)

        let inputFilesArguments = sourceFiles
            .flatMap { ["--input-files", $0 ] }

        let bundleSource = target.kind == .generic ? "module" : "finder"
        let description = "\(target.kind) module \(target.name)"

        let customArguments: [String]
        let customArgumentFile = context.package.directory.appending([".rswiftarguments"])

        do {
            let data = try String(contentsOfFile: customArgumentFile.string, encoding: .utf8)
            customArguments = data.components(separatedBy: .newlines)
        } catch {
            customArguments = []
        }
 
        return [
            .buildCommand(
                displayName: "R.swift generate resources for \(description)",
                executable: try context.tool(named: "rswift").path,
                arguments: [
                    "generate", rswiftPath.string,
                    "--input-type", "input-files",
                    "--bundle-source", bundleSource,
                ] + inputFilesArguments + customArguments,
                outputFiles: [rswiftPath]
            ),
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension RswiftGenerateInternalResources: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {

        let resourcesDirectoryPath = context.pluginWorkDirectory
            .appending(subpath: target.displayName)
            .appending(subpath: "Resources")

        try FileManager.default.createDirectory(atPath: resourcesDirectoryPath.string, withIntermediateDirectories: true)

        let rswiftPath = resourcesDirectoryPath.appending(subpath: "R.generated.swift")

        let description: String
        if let product = target.product {
            description = "\(product.kind) \(target.displayName)"
        } else {
            description = target.displayName
        }

        let customArguments: [String]
        let customArgumentFile = context.xcodeProject.directory.appending([".rswiftarguments"])

        do {
            let data = try String(contentsOfFile: customArgumentFile.string, encoding: .utf8)
            customArguments = data.components(separatedBy: .newlines)
        } catch {
            customArguments = []
        }

        return [
            .buildCommand(
                displayName: "R.swift generate resources for \(description)",
                executable: try context.tool(named: "rswift").path,
                arguments: [
                    "generate", rswiftPath.string,
                    "--target", target.displayName,
                    "--input-type", "xcodeproj",
                    "--bundle-source", "finder",
                ] + customArguments,
                outputFiles: [rswiftPath]
            ),
        ]
    }
}

#endif
