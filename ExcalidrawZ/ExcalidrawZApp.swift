import Foundation
import SwiftUI
import Logging
#if os(macOS)
import ServiceManagement
#endif

import SwiftyAlert
import ChocofordUI
#if os(macOS) && !APP_STORE
import Sparkle
#endif
import LLMCore
import LLMKit

extension Notification.Name {
    static let shouldHandleImport = Notification.Name("ShouldHandleImport")
    static let didImportToExcalidrawZ = Notification.Name("DidImportToExcalidrawZ")
    static let toggleWhatsNewSheet = Notification.Name("ToggleWhatsNewSheet")
    static let togglePrintModalSheet = Notification.Name("TogglePrintModalSheet")
    static let toggleSidebar = Notification.Name("ToggleSidebar")
    static let toggleInspector = Notification.Name("ToggleInspector")
    static let toggleShare = Notification.Name("ToggleShare")
    static let lockedContentDidReset = Notification.Name("LockedContentDidReset")
    static let lockedContentDidDeleteFile = Notification.Name("LockedContentDidDeleteFile")
}

extension LLMClient {
#if DEBUG
    static let shared = LLMClient(
        authProvider: .xcode(bundleID: "com.chocoford.excalidraw-Debug"),
        uploadProvider: .none,
        uploadPolicy: .automatic
    )
#else
    static let shared = LLMClient(
        authProvider: .appStore(
            bundleID: "com.chocoford.excalidraw",
            ascAppID: 6754812067,
            subscriptionGroupID: "21660497"
        ),
        uploadProvider: .none,
        uploadPolicy: .automatic
    )
#endif
}

@main
@MainActor
struct ExcalidrawZApp: App {
    @Environment(\.managedObjectContext) private var viewContext
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#elseif os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

#if os(macOS) && !APP_STORE
    private let updaterController: SPUStandardUpdaterController
#endif
    init() {
        LoggingSystem.bootstrap { label in
            var stdoutHandler = StreamLogHandler.standardOutput(label: label)
#if DEBUG
            stdoutHandler.logLevel = .debug
#else
            stdoutHandler.logLevel = .info
#endif
            return stdoutHandler
        }
        FeatureDiscoveryTips.configureIfAvailable()

#if os(macOS) && !APP_STORE
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
#endif

        if #available(macOS 13.0, *) {} else {
            UserDefaults.standard.set(1, forKey: "FolderStructureStyle")
        }

        var shouldRefreshSpotlightIndex = false
        let dateString = UserDefaults.standard.string(forKey: "LastSpotlightIndexRefreshTime")
        if let dateString,
           let date = try? Date(dateString, strategy: .iso8601),
           date < Date.now - 20 * 24 * 60 * 60 {
            shouldRefreshSpotlightIndex = true
        } else if dateString == nil {
            shouldRefreshSpotlightIndex = true
        }
        if shouldRefreshSpotlightIndex {
            let startupLogger = Logging.Logger(label: "ExcalidrawApp")
            Task {
                do {
                    try await PersistenceController.shared.refreshIndices()
                    UserDefaults.standard.set(Date.now.formatted(.iso8601), forKey: "LastSpotlightIndexRefreshTime")
                } catch {
                    startupLogger.error("Failed to refresh Spotlight index: \(error)")
                }
            }
        }

        let llmPersistenceProvider = LLMPersistenceProvider()

        let toolRegistry = ToolRegistry()
        let tools: [Tool] = [
            WebSearchTool(client: .shared),
            WebFetchTool(),
            CalculatorTool(),
            DateTimeTool(),
            FileAccessStatusTool(),
            ReadFileTool(),
            ReadCanvasImageTool(),
            AdjustElementsTool(),
            RenameFileTool(),
            ListAllFilesTool(),
            QueryFileHistoryTool(),
            RestoreFileHistoryTool(),
            ListLibrariesTool(),
            ListLibraryItemsTool(),
            QueryLibraryItemTool(),
            AddLibraryItemToCanvasTool(),
            FinalAnswerTool()
        ].map(LockedContentProtectedTool.init)
        ToolDisplayNameCache.register(tools)
        Task {
            await toolRegistry.register(tools)
        }

        self._llmState = StateObject(wrappedValue: LLMStateObject(
            llmClient: .shared,
            toolRegistry: toolRegistry,
            persistenceProvider: llmPersistenceProvider,
            streamPublishStrategy: .throttled(0.33)
        ))

        if AIChatPreferences.shared.isAIEnabled {
            Task {
                await LLMServiceActivationCoordinator.shared.restoreIfAIEnabled(reason: .appLaunch)
            }
        }

        Task.detached(priority: .background) {
            try? await Task.sleep(for: .seconds(15))
            await Self.runAttachmentGC()
        }
    }

    private static func runAttachmentGC() async {
        do {
            let blobs = try await PersistenceController.shared.aiConversationRepository.fetchAllFilesDataBlobs()
            let referenced = blobs.flatMap { blob -> [PersistedFile] in
                (try? JSONDecoder().decode([PersistedFile].self, from: blob)) ?? []
            }
            let referencedIDs = Set(referenced.compactMap { record -> String? in
                guard record.kind == .local else { return nil }
                return record.fileID
            })
            await PersistenceController.shared.aiChatAttachmentRepository.garbageCollect(
                referencedFileIDs: referencedIDs
            )
        } catch {
        }
    }

    @Environment(\.scenePhase) var scenePhase

    @StateObject private var appPrefernece = AppPreference()
    @StateObject private var store = Store.shared
#if os(macOS) && !APP_STORE
    @StateObject private var updateChecker = UpdateChecker()
#endif
    @StateObject private var llmState: LLMStateObject
    @StateObject private var aiChatState = AIChatState()
    @StateObject private var lockedContentState = LockedContentStateStore()
    @StateObject private var aiContainer = AIContainer()

    @State private var isArchiveFilesExporterPresented = false

    let server = ExcalidrawServer()
    let logger = Logging.Logger(label: "ExcalidrawApp")

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appPrefernece.appearance.colorScheme)
                .archiveFilesExporter(
                    isPresented: $isArchiveFilesExporterPresented,
                    context: PersistenceController.shared.container.viewContext,
                ) { _ in }
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(appPrefernece)
                .environmentObject(store)
                .environmentObject(aiChatState)
                .environmentObject(lockedContentState)
                .environmentObject(aiContainer)
                .llmProvider(state: llmState, client: .shared)
                .lockedContentAutoRelock(lockedContentState: lockedContentState)
                .onAppear {
#if os(macOS) && !APP_STORE
                    updateChecker.assignUpdater(updater: updaterController.updater)
#endif
                }
        }
        .handlesExternalEvents(matching: ["*"])
#if os(macOS) && !APP_STORE
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(checkForUpdatesViewModel: updateChecker)
            }
        }
#endif
#if os(macOS)
        .defaultSizeIfAvailable(CGSize(width: 1200, height: 700))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button {
                    NotificationCenter.default.post(
                        name: .shouldHandleNewDraw,
                        object: nil
                    )
                } label: {
                    Text(.localizable(.generalButtonCreateNewFile))
                }
                .keyboardShortcut("N", modifiers: .command)

                Button {
                    NotificationCenter.default.post(
                        name: .shouldHandleNewDrawFromClipboard,
                        object: nil
                    )
                } label: {
                    Text(.localizable(.whatsNewNewDrawFromClipboardTitle))
                }
                .keyboardShortcut("N", modifiers: [.command, .option, .shift])
            }

            CommandGroup(after: .printItem) {
                Button {
                    NotificationCenter.default.post(name: .togglePrintModalSheet, object: nil)
                } label: {
                    Text(.localizable(.menubarButtonPrint))
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            CommandGroup(after: .importExport) {
                Button {
                    let panel = ExcalidrawOpenPanel.importPanel
                    if panel.runModal() == .OK {
                        NotificationCenter.default.post(name: .shouldHandleImport, object: panel.urls)
                    }
                } label: {
                    Label(.localizable(.menubarButtonImport), systemSymbol: .squareAndArrowDown)
                }
                Button {
                    isArchiveFilesExporterPresented.toggle()
                } label: {
                    Label(.localizable(.menubarButtonExportAll), systemSymbol: .squareAndArrowUp)
                }
            }

            CommandGroup(before: .sidebar) {
                Button {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                } label: {
                    Text(.localizable(.menubarToggleSidebar))
                }
                .keyboardShortcut("0", modifiers: [.command])

                Button {
                    NotificationCenter.default.post(name: .toggleInspector, object: nil)
                } label: {
                    Text(.localizable(.menubarToggleLibrary))
                }
                .keyboardShortcut("0", modifiers: [.command, .option])

                Button {
                    NotificationCenter.default.post(name: .toggleShare, object: nil)
                } label: {
                    Text(.localizable(.menubarToggleShare))
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }

            CommandGroup(after: .help) {
                Button {
                    NotificationCenter.default.post(name: .toggleWhatsNewSheet, object: nil)
                } label: {
                    Text(.localizable(.whatsNewTitle))
                }
            }
        }
#endif

#if os(macOS)
        Settings {
            SettingsView()
                .swiftyAlert(logs: true)
                .containerSizeClassInjection()
                .preferredColorScheme(appPrefernece.appearance.colorScheme)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(appPrefernece)
                .environmentObject(store)
                .environmentObject(lockedContentState)
                .environmentObject(aiContainer)
                .llmProvider(state: llmState, client: .shared)
#if !APP_STORE
                .environmentObject(updateChecker)
#endif
        }
#endif
    }
}

fileprivate extension Scene {
    func defaultSizeIfAvailable(_ size: CGSize) -> some Scene {
        if #available(macOS 13.0, iOS 17.0, *) {
            return self.defaultSize(size)
        }
        else {
            return self
        }
    }
}
