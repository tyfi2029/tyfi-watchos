import SwiftUI

/// Shared async-load scaffolding (§ dispatch Task 8).
///
/// Existing screens each own a bespoke `@Published snapshot/error/loading` trio; this
/// is the canonical reusable form for new screens and a gradual refactor target. It
/// pairs a four-case `LoadState` with a `@MainActor Loader` over `API.shared.get` and
/// three token-styled placeholder subviews.
enum LoadState<T> {
    case loading
    case loaded(T)
    case empty
    case failed(String)

    var value: T? { if case let .loaded(v) = self { return v } else { return nil } }
    var isLoading: Bool { if case .loading = self { return true } else { return false } }
}

/// Drives a single GET endpoint into a `LoadState`. `isEmpty` lets a screen treat a
/// decoded-but-vacant payload (e.g. no sessions) as `.empty` rather than `.loaded`.
@MainActor
final class Loader<T: Decodable & Sendable>: ObservableObject {
    @Published private(set) var state: LoadState<T> = .loading

    private let path: String
    private let isEmpty: (T) -> Bool

    init(path: String, isEmpty: @escaping (T) -> Bool = { _ in false }) {
        self.path = path
        self.isEmpty = isEmpty
    }

    func load() async {
        state = .loading
        do {
            let value = try await API.shared.get(path, as: T.self)
            state = isEmpty(value) ? .empty : .loaded(value)
        } catch APIError.notAuthed {
            state = .failed("Pair watch to sync")
        } catch {
            state = .failed("Offline")
        }
    }
}

// MARK: - Reusable placeholder subviews

/// Centered progress spinner on the OLED background.
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .tint(Tokens.C.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.C.bg)
    }
}

/// Neutral "nothing here yet" state with an optional SF Symbol.
struct EmptyStateView: View {
    var symbol: String = "tray"
    var message: String = "Nothing yet"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Tokens.C.ink3)
            Text(message)
                .font(Type.body())
                .foregroundStyle(Tokens.C.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Tokens.S.hPad)
        .background(Tokens.C.bg)
    }
}

/// Failure state with the surfaced message and an optional retry action.
struct ErrorStateView: View {
    var message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Tokens.C.warn)
            Text(message)
                .font(Type.body())
                .foregroundStyle(Tokens.C.ink2)
                .multilineTextAlignment(.center)
            if let retry {
                PillButton(label: "Retry", color: Tokens.C.accent, action: retry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Tokens.S.hPad)
        .background(Tokens.C.bg)
    }
}
