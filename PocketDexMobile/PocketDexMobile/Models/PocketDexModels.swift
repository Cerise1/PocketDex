import Foundation
import UIKit

struct PocketDexHealthResponse: Decodable {
    let ok: Bool
    let timestamp: String?
    let deviceName: String?
}

struct PocketDexThreadsResponse: Decodable {
    let data: [PocketDexThreadSummary]
    let nextCursor: String?
}

struct PocketDexThreadResponse: Decodable {
    let thread: PocketDexThreadDetail?
}

struct PocketDexCreateThreadResponse: Decodable {
    let thread: PocketDexThreadSummary?
}

struct PocketDexProject: Decodable, Hashable {
    let name: String
    let path: String
    let root: String?
}

struct PocketDexCreateProjectResponse: Decodable {
    let ok: Bool?
    let project: PocketDexProject?
}

struct PocketDexUploadResponse: Decodable {
    let ok: Bool?
    let attachment: PocketDexPreparedAttachment?
}

struct PocketDexAckResponse: Decodable {
    let ok: Bool?
    let error: String?
    let accepted: Bool?
    let pending: Bool?
    let deduped: Bool?
    let retargeted: Bool?
    let dedupedFallbackTriggered: Bool?
    let traceID: String?
    let clientActionID: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case error
        case accepted
        case pending
        case deduped
        case retargeted
        case dedupedFallbackTriggered
        case traceID = "traceId"
        case clientActionID = "clientActionId"
    }
}

struct PocketDexConfigResponse: Decodable {
    let config: PocketDexRuntimeConfig?
}

struct PocketDexWorkspacesResponse: Decodable {
    let roots: [String]
}

enum PocketDexCodexAccessMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case fullAccess = "full-access"
    case workspaceWrite = "workspace-write"

    var id: PocketDexCodexAccessMode { self }

    var title: String {
        switch self {
        case .fullAccess:
            return "Full access"
        case .workspaceWrite:
            return "Workspace write"
        }
    }

    var detail: String {
        switch self {
        case .fullAccess:
            return "No sandbox restrictions."
        case .workspaceWrite:
            return "Scoped to the workspace."
        }
    }
}

struct PocketDexCodexPreferences: Codable, Hashable {
    var accessMode: PocketDexCodexAccessMode
    var internetAccessEnabled: Bool

    static let `default` = PocketDexCodexPreferences(
        accessMode: .fullAccess,
        internetAccessEnabled: true
    )

    private enum CodingKeys: String, CodingKey {
        case accessMode
        case internetAccessEnabled = "internetAccess"
    }
}

struct PocketDexRuntimeConfig: Decodable {
    let features: PocketDexRuntimeFeatures?
}

struct PocketDexRuntimeFeatures: Decodable {
    let steer: Bool?
}

struct PocketDexExternalRun: Codable, Hashable {
    let active: Bool
    let owner: String?
    let turnID: String?

    private enum CodingKeys: String, CodingKey {
        case active
        case owner
        case turnID = "turnId"
        case turnIDSnake = "turn_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedActive: Bool
        if let boolValue = try container.decodeIfPresent(Bool.self, forKey: .active) {
            decodedActive = boolValue
        } else if let intValue = try container.decodeIfPresent(Int.self, forKey: .active) {
            decodedActive = intValue != 0
        } else {
            decodedActive = false
        }
        active = decodedActive
        let decodedOwner = try container.decodeIfPresent(String.self, forKey: .owner)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        owner = (decodedOwner?.isEmpty == false) ? decodedOwner : nil
        let decodedTurnIDPrimary = try container.decodeIfPresent(String.self, forKey: .turnID)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedTurnIDSecondary = try container.decodeIfPresent(String.self, forKey: .turnIDSnake)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedTurnID = decodedTurnIDPrimary ?? decodedTurnIDSecondary
        turnID = (decodedTurnID?.isEmpty == false) ? decodedTurnID : nil
    }

    init(active: Bool, owner: String? = nil, turnID: String? = nil) {
        self.active = active
        self.owner = owner
        self.turnID = turnID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(active, forKey: .active)
        try container.encodeIfPresent(owner, forKey: .owner)
        try container.encodeIfPresent(turnID, forKey: .turnID)
    }
}

struct PocketDexThreadSummary: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let preview: String
    let modelProvider: String
    let createdAt: Double?
    let updatedAt: Double?
    let path: String?
    let cwd: String
    let cliVersion: String
    let externalRun: PocketDexExternalRun?

    var displayTitle: String {
        let trimmedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        let trimmedPreview = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPreview.isEmpty {
            return trimmedPreview
        }
        return "Untitled conversation"
    }

    var updatedDate: Date? {
        guard let updatedAt else { return nil }
        return Date.fromPocketDexTimestamp(updatedAt)
    }

    var isActive: Bool {
        externalRun?.active == true
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case preview
        case modelProvider
        case createdAt
        case updatedAt
        case path
        case cwd
        case cliVersion
        case externalRun
        case externalRunSnake = "external_run"
    }

    init(
        id: String,
        title: String?,
        preview: String,
        modelProvider: String,
        createdAt: Double?,
        updatedAt: Double?,
        path: String?,
        cwd: String,
        cliVersion: String,
        externalRun: PocketDexExternalRun?
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.modelProvider = modelProvider
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.path = path
        self.cwd = cwd
        self.cliVersion = cliVersion
        self.externalRun = externalRun
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
        modelProvider = try container.decodeIfPresent(String.self, forKey: .modelProvider) ?? ""
        createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Double.self, forKey: .updatedAt)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd) ?? ""
        cliVersion = try container.decodeIfPresent(String.self, forKey: .cliVersion) ?? ""
        externalRun =
            try container.decodeIfPresent(PocketDexExternalRun.self, forKey: .externalRun) ??
            (try container.decodeIfPresent(PocketDexExternalRun.self, forKey: .externalRunSnake))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(preview, forKey: .preview)
        try container.encode(modelProvider, forKey: .modelProvider)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(path, forKey: .path)
        try container.encode(cwd, forKey: .cwd)
        try container.encode(cliVersion, forKey: .cliVersion)
        try container.encodeIfPresent(externalRun, forKey: .externalRun)
    }
}

struct PocketDexThreadDetail: Decodable, Identifiable, Hashable {
    let id: String
    let title: String?
    let preview: String?
    let cwd: String
    let updatedAt: Double?
    let turns: [PocketDexTurn]
    let turnsOffset: Int?
    let turnsTotal: Int?
    let hasMoreTurns: Bool
    let externalRun: PocketDexExternalRun?

    var hasActiveRun: Bool {
        let hasRunningTurn = turns.contains { turn in
            let normalized = Self.normalizeTurnStatus(turn.status)
            guard !normalized.isEmpty else { return false }
            return Self.activeTurnStatuses.contains(normalized)
        }
        if hasRunningTurn { return true }

        // Guard against stale external-run states on brand-new/empty threads.
        if externalRun?.active == true, !turns.isEmpty {
            return true
        }
        return false
    }

    var displayTitle: String {
        let trimmedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        let previewValue = (preview ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !previewValue.isEmpty {
            return previewValue
        }
        return "Conversation"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case preview
        case cwd
        case updatedAt
        case turns
        case turnsOffset
        case turnsTotal
        case hasMoreTurns
        case externalRun
        case externalRunSnake = "external_run"
    }

    init(
        id: String,
        title: String?,
        preview: String?,
        cwd: String,
        updatedAt: Double?,
        turns: [PocketDexTurn],
        turnsOffset: Int?,
        turnsTotal: Int?,
        hasMoreTurns: Bool,
        externalRun: PocketDexExternalRun?
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.cwd = cwd
        self.updatedAt = updatedAt
        self.turns = turns
        self.turnsOffset = turnsOffset
        self.turnsTotal = turnsTotal
        self.hasMoreTurns = hasMoreTurns
        self.externalRun = externalRun
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd) ?? ""
        updatedAt = try container.decodeIfPresent(Double.self, forKey: .updatedAt)
        turns = try container.decodeIfPresent([PocketDexTurn].self, forKey: .turns) ?? []
        turnsOffset = try container.decodeIfPresent(Int.self, forKey: .turnsOffset)
        turnsTotal = try container.decodeIfPresent(Int.self, forKey: .turnsTotal)
        hasMoreTurns = try container.decodeIfPresent(Bool.self, forKey: .hasMoreTurns) ?? false
        externalRun =
            try container.decodeIfPresent(PocketDexExternalRun.self, forKey: .externalRun) ??
            (try container.decodeIfPresent(PocketDexExternalRun.self, forKey: .externalRunSnake))
    }

    private static let activeTurnStatuses: Set<String> = [
        "pending",
        "running",
        "inprogress",
        "active",
        "started",
        "executing",
    ]

    private static func normalizeTurnStatus(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

struct PocketDexTurn: Decodable, Identifiable, Hashable {
    let id: String
    let status: String
    let items: [PocketDexThreadItem]
    let createdAt: Double?
    let updatedAt: Double?
    let startedAt: Double?
    let completedAt: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case items
        case createdAt
        case createdAtSnake = "created_at"
        case updatedAt
        case updatedAtSnake = "updated_at"
        case startedAt
        case startedAtSnake = "started_at"
        case completedAt
        case completedAtSnake = "completed_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        items = try container.decodeIfPresent([PocketDexThreadItem].self, forKey: .items) ?? []
        createdAt =
            Self.decodeTimestamp(from: container, forKey: .createdAt) ??
            Self.decodeTimestamp(from: container, forKey: .createdAtSnake)
        updatedAt =
            Self.decodeTimestamp(from: container, forKey: .updatedAt) ??
            Self.decodeTimestamp(from: container, forKey: .updatedAtSnake)
        startedAt =
            Self.decodeTimestamp(from: container, forKey: .startedAt) ??
            Self.decodeTimestamp(from: container, forKey: .startedAtSnake)
        completedAt =
            Self.decodeTimestamp(from: container, forKey: .completedAt) ??
            Self.decodeTimestamp(from: container, forKey: .completedAtSnake)
    }

    private static func decodeTimestamp(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if let numeric = Double(trimmed) {
                return numeric
            }
            let parsed = ISO8601DateFormatter().date(from: trimmed)?.timeIntervalSince1970
            return parsed
        }
        return nil
    }
}

struct PocketDexThreadItem: Decodable, Identifiable, Hashable {
    let id: String
    let type: String
    let text: String?
    let userContent: [PocketDexUserInput]
    let summary: [String]
    let reasoningContent: [String]
    let command: String?
    let cwd: String?
    let durationMs: Double?
    let commandActions: [PocketDexCommandAction]
    let aggregatedOutput: String?
    let status: String?
    let diff: String?
    let changes: [PocketDexFileChange]

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case text
        case content
        case summary
        case command
        case cwd
        case durationMs
        case durationMsSnake = "duration_ms"
        case commandActions
        case commandActionsSnake = "command_actions"
        case aggregatedOutput
        case aggregatedOutputSnake = "aggregated_output"
        case status
        case diff
        case changes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        text = try container.decodeIfPresent(String.self, forKey: .text)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
        durationMs =
            try container.decodeIfPresent(Double.self, forKey: .durationMs) ??
            (try container.decodeIfPresent(Double.self, forKey: .durationMsSnake))
        commandActions =
            try container.decodeIfPresent([PocketDexCommandAction].self, forKey: .commandActions) ??
            (try container.decodeIfPresent([PocketDexCommandAction].self, forKey: .commandActionsSnake)) ??
            []
        aggregatedOutput =
            try container.decodeIfPresent(String.self, forKey: .aggregatedOutput) ??
            (try container.decodeIfPresent(String.self, forKey: .aggregatedOutputSnake))
        status = try container.decodeIfPresent(String.self, forKey: .status)
        diff = try container.decodeIfPresent(String.self, forKey: .diff)
        changes = try container.decodeIfPresent([PocketDexFileChange].self, forKey: .changes) ?? []
        summary = try container.decodeIfPresent([String].self, forKey: .summary) ?? []

        if type == "userMessage" {
            userContent = try container.decodeIfPresent([PocketDexUserInput].self, forKey: .content) ?? []
            reasoningContent = []
        } else if type == "reasoning" {
            reasoningContent = try container.decodeIfPresent([String].self, forKey: .content) ?? []
            userContent = []
        } else {
            userContent = []
            reasoningContent = []
        }
    }
}

struct PocketDexUserInput: Decodable, Hashable {
    let type: String
    let text: String?
    let path: String?
    let url: String?
    let name: String?
}

struct PocketDexFileChange: Decodable, Hashable {
    let path: String
    let kind: String
    let diff: String

    private enum CodingKeys: String, CodingKey {
        case path
        case kind
        case diff
    }

    private struct NestedKind: Decodable {
        let type: String?
        let movePath: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case movePath = "move_path"
        }
    }

    init(path: String, kind: String, diff: String) {
        self.path = path
        self.kind = kind
        self.diff = diff
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        diff = try container.decode(String.self, forKey: .diff)

        if let directKind = try? container.decode(String.self, forKey: .kind) {
            let trimmed = directKind.trimmingCharacters(in: .whitespacesAndNewlines)
            kind = trimmed.isEmpty ? "update" : trimmed
            return
        }

        if let nestedKind = try? container.decode(NestedKind.self, forKey: .kind) {
            let normalizedType = nestedKind.type?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let normalizedType, !normalizedType.isEmpty {
                if normalizedType == "update",
                   let movePath = nestedKind.movePath?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !movePath.isEmpty
                {
                    kind = "move"
                } else {
                    kind = normalizedType
                }
                return
            }
            if let movePath = nestedKind.movePath?.trimmingCharacters(in: .whitespacesAndNewlines),
               !movePath.isEmpty
            {
                kind = "move"
                return
            }
        }

        kind = "update"
    }
}

struct PocketDexCommandAction: Decodable, Hashable {
    let type: String
    let command: String?
    let name: String?
    let path: String?
    let query: String?
}

struct PocketDexPreparedAttachment: Codable, Hashable {
    let type: String
    let path: String
    let name: String?
}

struct PendingImageAttachment: Identifiable, Equatable {
    let id: UUID
    let filename: String
    let mimeType: String
    let data: Data
    let previewImage: UIImage?

    nonisolated init(
        id: UUID = UUID(),
        filename: String,
        mimeType: String,
        data: Data,
        previewImage: UIImage? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
        self.previewImage = previewImage ?? UIImage(data: data)
    }

    var isImage: Bool {
        if mimeType.lowercased().hasPrefix("image/") {
            return true
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        return [
            "png",
            "jpg",
            "jpeg",
            "gif",
            "webp",
            "bmp",
            "tif",
            "tiff",
            "heic",
            "heif",
            "avif",
            "svg",
        ].contains(ext)
    }

    static func == (lhs: PendingImageAttachment, rhs: PendingImageAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

struct ConversationTimelineItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case userText(String)
        case userImage(path: String?, remoteURL: String?)
        case userImageData(Data)
        case userFile(name: String, path: String?)
        case assistantMarkdown(String)
        case plan(String)
        case reasoning(summary: [String], content: [String])
        case command(command: String, output: String, status: String, durationMs: Double?, actions: [PocketDexCommandAction])
        case fileChange(status: String, changes: [PocketDexFileChange])
        case contextCompaction
        case system(label: String, detail: String?)
    }

    let id: String
    let kind: Kind
    let isFinal: Bool
    let workedMs: Double?

    init(id: String, kind: Kind, isFinal: Bool = false, workedMs: Double? = nil) {
        self.id = id
        self.kind = kind
        self.isFinal = isFinal
        self.workedMs = workedMs
    }
}

extension Date {
    static func fromPocketDexTimestamp(_ value: Double) -> Date {
        if value > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: value / 1000)
        }
        return Date(timeIntervalSince1970: value)
    }
}
