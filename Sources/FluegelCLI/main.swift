import FluegelCore
import Foundation

struct CLI {
    let arguments: [String]

    func run() throws -> Int32 {
        guard let command = arguments.first else {
            printHelp()
            return 2
        }

        switch command {
        case "status":
            return try status()
        case "run":
            return try runCommand(Array(arguments.dropFirst()))
        case "allow":
            return try allow(Array(arguments.dropFirst()))
        case "permissions":
            return try permissions(Array(arguments.dropFirst()))
        case "audit":
            return try audit(Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            printHelp()
            return 0
        default:
            fputs("unknown command: \(command)\n", stderr)
            printHelp()
            return 2
        }
    }

    private func status() throws -> Int32 {
        let response = try send(.init(token: token(), action: .status))
        print(response.message)
        if let config = response.config {
            print("commands: \(config.commands.count)")
        }
        return response.ok ? 0 : 1
    }

    private func runCommand(_ args: [String]) throws -> Int32 {
        let splitArgs = args.first == "--" ? Array(args.dropFirst()) : args
        guard let path = splitArgs.first, path.hasPrefix("/") else {
            fputs("usage: fluegel run -- /full/path [args...]\n", stderr)
            return 2
        }
        let request = RunRequest(
            executablePath: path,
            arguments: Array(splitArgs.dropFirst()),
            cwd: FileManager.default.currentDirectoryPath
        )
        let response = try send(.init(token: token(), action: .run, run: request))
        if let result = response.result {
            print(result.stdout, terminator: "")
            fputs(result.stderr, stderr)
            return result.exitCode
        }
        fputs(response.message + "\n", stderr)
        return response.ok ? 0 : 1
    }

    private func allow(_ args: [String]) throws -> Int32 {
        guard let subcommand = args.first else {
            fputs("usage: fluegel allow list|add|remove\n", stderr)
            return 2
        }

        switch subcommand {
        case "list":
            let response = try send(.init(token: token(), action: .listWhitelist))
            for command in response.config?.commands ?? [] {
                print("\(command.enabled ? "enabled" : "disabled") \(command.executablePath) \(command.permissions.map(\.rawValue).sorted().joined(separator: ","))")
            }
            return response.ok ? 0 : 1
        case "add":
            return try addAllow(Array(args.dropFirst()))
        case "remove":
            guard let path = value(after: "--path", in: Array(args.dropFirst())), path.hasPrefix("/") else {
                fputs("usage: fluegel allow remove --path /full/path\n", stderr)
                return 2
            }
            let response = try send(.init(token: token(), action: .removeWhitelist, executablePath: path))
            print(response.message)
            return response.ok ? 0 : 1
        default:
            fputs("unknown allow command: \(subcommand)\n", stderr)
            return 2
        }
    }

    private func addAllow(_ args: [String]) throws -> Int32 {
        guard let path = value(after: "--path", in: args), path.hasPrefix("/") else {
            fputs("usage: fluegel allow add --path /full/path --permission reminders [--name name]\n", stderr)
            return 2
        }
        let name = value(after: "--name", in: args) ?? URL(fileURLWithPath: path).lastPathComponent
        let permissionNames = values(after: "--permission", in: args)
        let permissions = Set(permissionNames.compactMap(PermissionKind.init(rawValue:)))
        guard !permissions.isEmpty else {
            fputs("at least one valid --permission is required; currently: reminders\n", stderr)
            return 2
        }
        let command = CommandEntry(name: name, executablePath: path, permissions: permissions)
        let response = try send(.init(token: token(), action: .addWhitelist, command: command))
        print(response.message)
        return response.ok ? 0 : 1
    }

    private func permissions(_ args: [String]) throws -> Int32 {
        guard args.count >= 2, let permission = PermissionKind(rawValue: args[1]) else {
            fputs("usage: fluegel permissions status|request reminders\n", stderr)
            return 2
        }
        let action: BridgeAction
        switch args[0] {
        case "status":
            action = .permissionStatus
        case "request":
            action = .requestPermission
        default:
            fputs("usage: fluegel permissions status|request reminders\n", stderr)
            return 2
        }
        let response = try send(.init(token: token(), action: action, permission: permission))
        print(response.permissionStatus?.rawValue ?? response.message)
        return response.ok ? 0 : 1
    }

    private func audit(_ args: [String]) throws -> Int32 {
        guard args.first == "list" || args.first == nil else {
            fputs("usage: fluegel audit list [--limit n]\n", stderr)
            return 2
        }
        let limit = value(after: "--limit", in: args).flatMap(Int.init) ?? 20
        guard limit > 0 else {
            fputs("limit must be positive\n", stderr)
            return 2
        }
        let response = try send(.init(token: token(), action: .auditList, auditLimit: limit))
        for entry in response.auditEntries ?? [] {
            print("\(entry.timestamp.formatted(date: .numeric, time: .standard)) \(entry.decision.rawValue) \(entry.executablePath) \(entry.reason)")
        }
        return response.ok ? 0 : 1
    }

    private func send(_ request: BridgeRequest) throws -> BridgeResponse {
        let timeout = max(10, (request.run?.timeoutSeconds ?? 0) + 5)
        return try BridgeClient(timeout: timeout).send(request)
    }

    private func token() throws -> String {
        try TokenStore().token()
    }

    private func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }

    private func values(after flag: String, in args: [String]) -> [String] {
        args.indices.compactMap { index in
            args[index] == flag && args.indices.contains(index + 1) ? args[index + 1] : nil
        }
    }

    private func printHelp() {
        print("""
        fluegel status
        fluegel run -- /full/path [args...]
        fluegel allow list
        fluegel allow add --path /full/path --permission reminders [--name name]
        fluegel allow remove --path /full/path
        fluegel permissions status reminders
        fluegel permissions request reminders
        fluegel audit list [--limit n]
        """)
    }
}

do {
    exit(try CLI(arguments: Array(CommandLine.arguments.dropFirst())).run())
} catch {
    fputs(error.localizedDescription + "\n", stderr)
    exit(1)
}
