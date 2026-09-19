import AppKit
import AuthenticationServices
import Foundation

@MainActor
final class OAuthSignInService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthSignInService()

    /// OAuth sign-in page (opens system browser sheet; returns via `nest://` callback).
    static var loginURL: URL {
        if let custom = UserDefaults.standard.string(forKey: "nestAuthLoginURL"), let url = URL(string: custom) {
            return url
        }
        return URL(string: "https://getnestapp.vercel.app/login?client=mac")!
    }

    private var activeSession: ASWebAuthenticationSession?

    func signIn() async throws -> NestAuthSession {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: Self.loginURL,
                callbackURLScheme: "nest"
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL, let parsed = Self.parseCallback(callbackURL) else {
                    continuation.resume(throwing: OAuthSignInError.invalidCallback)
                    return
                }
                continuation.resume(returning: parsed)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.activeSession = session
            if !session.start() {
                continuation.resume(throwing: OAuthSignInError.couldNotStart)
            }
        }
    }

    static func parseCallback(_ url: URL) -> NestAuthSession? {
        guard url.scheme?.lowercased() == "nest",
              url.host?.lowercased() == "auth",
              url.path == "/callback" else { return nil }

        let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "token" })?
            .value
        guard let token, !token.isEmpty else { return nil }

        let claims = JWTClaimsParser.basicClaims(from: token)
        return NestAuthSession(
            accessToken: token,
            email: claims?.email,
            displayName: claims?.name,
            signedInAt: Date()
        )
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? NSApp.windows.first!
    }
}

enum OAuthSignInError: LocalizedError {
    case invalidCallback
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Sign-in did not return a valid Nest callback."
        case .couldNotStart:
            return "Could not open the sign-in window."
        }
    }
}

/// Minimal JWT payload decode (no signature verify on device — token issued by Nest web).
private enum JWTClaimsParser {
    struct Claims {
        let email: String?
        let name: String?
    }

    static func basicClaims(from jwt: String) -> Claims? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        guard let data = base64URLDecode(payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return Claims(
            email: json["email"] as? String,
            name: json["name"] as? String
        )
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 { base64 += String(repeating: "=", count: padding) }
        return Data(base64Encoded: base64)
    }
}
