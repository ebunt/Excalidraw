import Foundation

/// Builds a live `AIContext` from the current canvas state.
///
/// Reads selected element IDs from `ExcalidrawCoordinatorRegistry.shared` and
/// optionally fetches a scene snapshot to extract text labels and a summary.
/// Used by `LocalAITestViewModel` (and future canvas-aware AI features) so
/// requests carry real editor state rather than hard-coded test data.
@MainActor
final class CanvasAIContextBuilder {
    init() {}

    /// Build an `AIContext` reflecting the current state of the normal canvas.
    ///
    /// - Parameter documentTitle: Optional document name from `FileState`.
    ///   Pass `nil` when the caller (e.g. the Settings test panel) doesn't
    ///   have access to `FileState`.
    func build(documentTitle: String? = nil) async -> AIContext {
        let coordinator = ExcalidrawCoordinatorRegistry.shared.coordinator(for: .normal)
        let selectedIDs = coordinator?.selectedElementIDs ?? []

        var selectedText: [String] = []
        var sceneSummary: String?

        if let coordinator,
           let snapshot = try? await coordinator.getCurrentFileSnapshot() {
            let totalCount = snapshot.elements.count
            sceneSummary = "\(totalCount) element\(totalCount == 1 ? "" : "s")"

            if !selectedIDs.isEmpty {
                let selectedSet = Set(selectedIDs)
                selectedText = snapshot.elements.compactMap { element -> String? in
                    guard case .object(let obj) = element,
                          case .string(let id) = obj["id"],
                          selectedSet.contains(id),
                          case .string(let text) = obj["text"],
                          !text.isEmpty else {
                        return nil
                    }
                    return text
                }
            }
        }

        return AIContext(
            documentTitle: documentTitle,
            selectedElementIDs: selectedIDs,
            selectedText: selectedText,
            sceneSummary: sceneSummary
        )
    }
}
