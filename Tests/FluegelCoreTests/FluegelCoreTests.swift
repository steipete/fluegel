import Foundation
import Testing
@testable import FluegelCore

@Suite("FluegelCore")
struct FluegelCoreTests {
    @Test("config store round trips private JSON")
    func configStoreRoundTrip() throws {
        let directory = try temporaryDirectory()
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let config = FluegelConfig(commands: [
            CommandEntry(
                name: "rem",
                executablePath: "/opt/homebrew/bin/rem",
                permissions: [.reminders],
                createdAt: date,
                updatedAt: date
            )
        ])

        try store.save(config)

        #expect(try store.load() == config)
    }

    @Test("whitelist requires exact enabled full path")
    func whitelistExactPath() throws {
        let evaluator = WhitelistEvaluator()
        let config = FluegelConfig(commands: [
            CommandEntry(name: "rem", executablePath: "/opt/homebrew/bin/rem", permissions: [.reminders])
        ])

        let allowed = try evaluator.entry(
            for: RunRequest(executablePath: "/opt/homebrew/bin/rem", arguments: ["lists"]),
            in: config
        )
        #expect(allowed.name == "rem")
        #expect(throws: WhitelistError.notWhitelisted("/usr/local/bin/rem")) {
            _ = try evaluator.entry(
                for: RunRequest(executablePath: "/usr/local/bin/rem", arguments: []),
                in: config
            )
        }
    }

    @Test("audit log appends JSON lines")
    func auditLogAppend() throws {
        let directory = try temporaryDirectory()
        let store = AuditLogStore(url: directory.appendingPathComponent("audit.jsonl"))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = AuditEntry(
            timestamp: date,
            decision: .denied,
            executablePath: "/opt/homebrew/bin/rem",
            arguments: ["lists"],
            cwd: nil,
            requester: "tester",
            permissions: [.reminders],
            exitCode: nil,
            stdoutBytes: 0,
            stderrBytes: 0,
            reason: "nope"
        )
        let second = AuditEntry(
            timestamp: date.addingTimeInterval(1),
            decision: .allowed,
            executablePath: "/opt/homebrew/bin/rem",
            arguments: ["lists"],
            cwd: nil,
            requester: "tester",
            permissions: [.reminders],
            exitCode: 0,
            stdoutBytes: 2,
            stderrBytes: 0,
            reason: "ok"
        )

        try store.append(first)
        try store.append(second)

        #expect(try store.entries(limit: 10) == [first, second])
        #expect(try store.entries(limit: 1) == [second])
        #expect(try store.entries(limit: -1) == [])
    }

    @Test("command runner drains large output while process runs")
    func commandRunnerDrainsLargeOutput() throws {
        let result = try CommandRunner().run(RunRequest(
            executablePath: "/bin/sh",
            arguments: ["-c", "yes x | head -c 200000"],
            timeoutSeconds: 5
        ))

        #expect(result.exitCode == 0)
        #expect(result.stdout.utf8.count == 200_000)
    }

    @Test("command runner kills a timed out process that ignores term")
    func commandRunnerKillsTimedOutProcess() throws {
        let directory = try temporaryDirectory()
        let pidFile = directory.appendingPathComponent("pid")
        let childPidFile = directory.appendingPathComponent("child-pid")

        #expect(throws: CommandRunnerError.timedOut) {
            _ = try CommandRunner().run(RunRequest(
                executablePath: "/bin/sh",
                arguments: ["-c", "echo $$ > '\(pidFile.path)'; sleep 30 & echo $! > '\(childPidFile.path)'; trap '' TERM; while true; do sleep 1; done"],
                timeoutSeconds: 0.2
            ))
        }

        let pid = try Int32(String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))
        let childPid = try Int32(String(contentsOf: childPidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(pid != nil)
        if let pid {
            #expect(kill(pid, 0) == -1)
        }
        #expect(childPid != nil)
        if let childPid {
            #expect(kill(childPid, 0) == -1)
        }
    }

    @Test("command runner kills surviving children after the timed out parent exits")
    func commandRunnerKillsChildAfterParentExits() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let childPidFile = directory.appendingPathComponent("child-pid")

        defer {
            if let contents = try? String(contentsOf: childPidFile, encoding: .utf8),
               let pid = Int32(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                kill(pid, SIGKILL)
            }
        }
        // Reset the test host's inherited SIGTERM mask only inside the fixture.
        #expect(throws: CommandRunnerError.timedOut) {
            _ = try CommandRunner().run(RunRequest(
                executablePath: "/usr/bin/perl",
                arguments: [
                    "-e",
                    """
                    use POSIX qw(SIG_UNBLOCK SIGTERM);
                    $SIG{TERM} = 'DEFAULT';
                    POSIX::sigprocmask(SIG_UNBLOCK, POSIX::SigSet->new(SIGTERM)) or die "sigprocmask: $!";
                    defined(my $child = fork()) or die "fork: $!";
                    if ($child == 0) {
                        $SIG{TERM} = 'IGNORE';
                        open(my $file, '>', $ARGV[0]) or die "pid file: $!";
                        print $file "$$\\n";
                        close($file);
                    }
                    sleep 30;
                    """,
                    childPidFile.path,
                ],
                timeoutSeconds: 2
            ))
        }

        let childPID = try #require(Int32(
            String(contentsOf: childPidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        // Orphan reaping can lag the signal delivery briefly.
        let deadline = Date().addingTimeInterval(2)
        while kill(childPID, 0) == 0 && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(kill(childPID, 0) == -1)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FluegelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
