import SwiftUI

/// Shown when WatchAuth.shared.isPaired == false.
/// User enters the 6-digit code from Settings → Apple Watch on life.tyfi.fyi.
struct PairingView: View {
    let onPaired: () -> Void

    @State private var digits = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 38))
                        .foregroundStyle(Tokens.C.accent)
                        .padding(.top, 8)

                    Text("Pair Watch")
                        .font(Type.label)
                        .foregroundStyle(Tokens.C.ink)

                    Text("Open TyFi on iPhone,\ngo to Settings → Apple Watch\nand generate a 6-digit code.")
                        .font(Type.caption)
                        .foregroundStyle(Tokens.C.ink2)
                        .multilineTextAlignment(.center)

                    TextField("000000", text: $digits)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(Tokens.C.accent)
                        .focused($focused)
                        .onChange(of: digits) { _, new in
                            let filtered = String(new.filter { $0.isNumber }.prefix(6))
                            digits = filtered
                            if filtered.count == 6 {
                                Task { await redeem(filtered) }
                            }
                        }

                    if let err = errorMsg {
                        Text(err)
                            .font(Type.caption)
                            .foregroundStyle(Tokens.C.bad)
                            .multilineTextAlignment(.center)
                    }

                    if isLoading {
                        ProgressView()
                            .tint(Tokens.C.accent)
                    }
                }
                .padding(Tokens.S.gutter * 2)
            }
            .onAppear { focused = true }
        }
    }

    private func redeem(_ code: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMsg = nil
        defer { isLoading = false }
        do {
            struct RedeemBody: Encodable { let code: String; let device_name: String }
            struct RedeemResponse: Decodable { let token: String }
            let result = try await API.shared.postPublic(
                "/api/watch/auth/redeem",
                body: RedeemBody(code: code, device_name: "Apple Watch Ultra 2"),
                as: RedeemResponse.self
            )
            WatchAuth.shared.set(result.token)
            onPaired()
        } catch APIError.http(let status) {
            errorMsg = status == 401 ? "Invalid or expired code" : "Server error (\(status))"
            digits = ""
        } catch {
            errorMsg = error.localizedDescription
            digits = ""
        }
    }
}

#Preview {
    PairingView(onPaired: {})
}
