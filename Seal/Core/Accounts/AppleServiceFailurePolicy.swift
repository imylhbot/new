import Foundation

enum AppleServiceFailurePolicy {
    /// AltSign wraps an HTML HTTP 503 body as ALTServerError(code: 1).
    /// Do not infer an HTTP status from the numeric NSError code alone.
    static func isServiceUnavailable(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        for _ in 0..<5 {
            guard let item = current else { break }
            let message = item.localizedDescription.lowercased()
            if item.domain.contains("ALTServerError"),
               message.contains("503 service temporarily unavailable") || message.contains("503 service unavailable") {
                return true
            }
            current = item.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    static func shouldRetryAuthentication(_ error: Error, retries: Int, requestedVerification: Bool) -> Bool {
        isServiceUnavailable(error) && !requestedVerification && retries < 2
    }

    static func serviceUnavailableFailure() -> ImportFailure {
        ImportFailure(
            title: "Apple 服务暂不可用",
            reason: "认证服务返回 HTTP 503，未能完成登录。这不是密码错误，也不是配对文件错误。已保存账号不会因此失效。",
            recovery: "稍后重试；若持续出现，请检查代理或更换网络。无需删除账号或配对文件。",
            code: "SEAL-NET-503"
        )
    }

    static func isNetworkError(_ error: Error) -> Bool {
        if isServiceUnavailable(error) { return true }
        if let urlError = error as? URLError {
            return networkCodes.contains(urlError.code)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            if networkCodes.contains(code) {
                return true
            }
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           isNetworkError(underlying) {
            return true
        }

        let message = nsError.localizedDescription.lowercased()
        return networkFragments.contains(where: message.contains)
    }

    static func networkFailure(
        underlying _: Error? = nil,
        title: String = "网络不可用",
        reason: String = "当前无法连接 Apple 服务。已保存的 Apple ID 不会受到影响。",
        recovery: String = "网络恢复后重试",
        code: String = "SEAL-NET-101"
    ) -> ImportFailure {
        ImportFailure(
            title: title,
            reason: reason,
            recovery: recovery,
            code: code
        )
    }

    static func verificationFailureReason(
        for failure: ImportFailure
    ) -> AccountVerificationFailureReason? {
        switch failure.code {
        case "SEAL-AUTH-102":
            return .credentialsRejected
        case "SEAL-AUTH-105":
            return .localCredentialsMissing
        case "SEAL-AUTH-106":
            return .localCredentialsMismatch
        default:
            // SEAL-AUTH-107（会话过期）不再标记 ID 失效：
            // 已保存密码，下次签名会自动重登，不应因为一次会话过期就把 ID 标记为需要重新验证
            return nil
        }
    }

    static func shouldRequireReverification(_ failure: ImportFailure) -> Bool {
        verificationFailureReason(for: failure) != nil
    }

    static func isTransient(_ failure: ImportFailure) -> Bool {
        failure.code.hasPrefix("SEAL-NET-")
            || failure.code.hasPrefix("SEAL-ANI-")
            || failure.code == "SEAL-CERT-205"
    }

    private static let networkCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .internationalRoamingOff,
        .dataNotAllowed,
        .callIsActive,
        .resourceUnavailable
    ]

    private static let networkFragments = [
        "network",
        "timed out",
        "timeout",
        "not connected",
        "offline",
        "cannot connect",
        "could not connect",
        "cannot find host",
        "dns"
    ]
}
