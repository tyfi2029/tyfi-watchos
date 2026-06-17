import Foundation

/// §3 POST verification infra. Intercepts requests on an injected URLSession and
/// returns canned `{ok,data}` / `{ok:false,error}` envelopes WITHOUT touching the
/// network — so action paths are verified against the Simulator only, never live.
///
/// CAVEAT (watchOS 11.5 sim, Xcode 16.4): URLProtocol interception is reliable for
/// bodyless GETs but does NOT intercept POSTs that carry an `httpBody` here — such
/// requests escape to the network. POST contract verification therefore runs at the
/// encode/decode layer (see PostContractTests). This type is kept for GET mocking and
/// for the morning, when the POST-body interception path can be revisited.
///
/// Usage:
///   MockURLProtocol.handler = { req in
///       MockURLProtocol.captured = req.tyfi_bodyData   // assert the request body shape
///       return (200, Data(#"{"ok":true,"data":{...}}"#.utf8))
///   }
///   let cfg = URLSessionConfiguration.ephemeral
///   cfg.protocolClasses = [MockURLProtocol.self]
///   let api = API(session: URLSession(configuration: cfg))
final class MockURLProtocol: URLProtocol {
    /// Returns (statusCode, bodyData) for a given request. Set per-test.
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    /// The most recent intercepted request's body, captured for assertions.
    nonisolated(unsafe) static var captured: Data?

    static func reset() { handler = nil; captured = nil }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        MockURLProtocol.captured = request.tyfi_bodyData
        let (status, data) = handler(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// URLSession often moves `httpBody` into `httpBodyStream`; read whichever is set.
    var tyfi_bodyData: Data? {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buf, maxLength: bufSize)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}
