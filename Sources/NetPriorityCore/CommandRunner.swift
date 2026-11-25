import Foundation

public struct CommandResult {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}

public enum CommandRunner {
    @discardableResult
    public static func run(_ executable: String, _ args: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return CommandResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.wait()
        process.waitUntilExit()

        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, stdout: outStr, stderr: errStr)
    }

    @discardableResult
    public static func runNetworkSetup(_ args: [String]) throws -> String {
        let direct = run("/usr/sbin/networksetup", args)
        if direct.exitCode == 0 {
            return direct.stdout
        }

        let combined = (direct.stderr + " " + direct.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = combined.lowercased()
        let needsPrivilege = lower.contains("authorization")
            || lower.contains("privilege")
            || lower.contains("permission")
            || lower.contains("not allowed")
            || lower.contains("root")
            || lower.contains("sudo")
            || lower.contains("admin")
            || lower.contains("commit")
            || lower.contains("error: -")

        if needsPrivilege {
            let quotedArgs = args.map { shellQuote($0) }.joined(separator: " ")
            let shellCmd = "/usr/sbin/networksetup \(quotedArgs)"
            let escapedAppleScript = shellCmd
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let osa = run("/usr/bin/osascript", ["-e", "do shell script \"\(escapedAppleScript)\" with administrator privileges"])
            if osa.exitCode == 0 {
                return osa.stdout
            }
            let osaDetail = (osa.stderr + " " + osa.stdout).trimmingCharacters(in: .whitespacesAndNewlines)
            throw NetworkManagerError.commandFailed(command: "networksetup \(args.first ?? "")", detail: osaDetail.isEmpty ? combined : osaDetail)
        }

        throw NetworkManagerError.commandFailed(
            command: "networksetup \(args.first ?? "")",
            detail: combined.isEmpty ? "退出码 \(direct.exitCode)" : combined
        )
    }

    private static func shellQuote(_ arg: String) -> String {
        "'" + arg.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
