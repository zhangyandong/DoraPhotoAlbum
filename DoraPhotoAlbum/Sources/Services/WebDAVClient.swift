import Foundation

struct WebDAVConfig {
    var host: String
    var username: String
    var password: String
}

class WebDAVClient: NSObject, XMLParserDelegate {
    private let config: WebDAVConfig
    private var session: URLSession
    
    // Parsing state
    private var currentElement = ""
    private var currentHref = ""
    private var currentContentType = ""
    private var currentLastModified = ""
    private var currentIsCollection = false
    
    private var resources: [WebDAVResource] = []
    private var parseCompletion: (([WebDAVResource]) -> Void)?
    
    struct WebDAVResource {
        let href: String
        let contentType: String
        let lastModified: Date?
        var isCollection: Bool = false // Flag to track if resource is a collection (directory)
        
        var isDirectory: Bool {
            // Check multiple indicators:
            // 1. Check if explicitly marked as collection
            if isCollection {
                return true
            }
            // 2. Check content type (most reliable)
            if contentType.lowercased().contains("directory") || contentType.lowercased().contains("collection") {
                return true
            }
            // 3. Fallback: check trailing slash on href
            if href.hasSuffix("/") {
                return true
            }
            return false
        }
    }
    
    init(config: WebDAVConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 10
        configuration.urlCache = nil // Disable cache to ensure we get fresh data
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
        super.init()
    }
    
    // List directory with both files and folders
    func listDirectoryContents(path: String, completion: @escaping ([WebDAVResource]) -> Void) {
        let cleanHost = config.host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        
        guard let url = URL(string: cleanHost + cleanPath) else {
            print("WebDAV: Invalid URL - host: \(cleanHost), path: \(cleanPath)")
            DispatchQueue.main.async {
                completion([])
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.addValue("1", forHTTPHeaderField: "Depth")
        
        let loginString = String(format: "%@:%@", config.username, config.password)
        guard let loginData = loginString.data(using: .utf8) else {
            print("WebDAV: Failed to encode login credentials")
            DispatchQueue.main.async {
                completion([])
            }
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("WebDAV Error: \(error.localizedDescription)")
                print("WebDAV Error Code: \((error as NSError).code)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            guard let self = self, let data = data else {
                print("WebDAV: No data received")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 207 {
                    print("WebDAV HTTP Error: \(httpResponse.statusCode)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("WebDAV Response: \(responseString.prefix(500))")
                    }
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
            }
            
            self.parseWebDAVResponse(data) { resources in
                // Filter out the current directory itself
                // Handle both absolute and relative hrefs
                let filtered = resources.filter { res in
                    var hrefPath = res.href
                    // If href is absolute URL, extract path component
                    if hrefPath.hasPrefix("http://") || hrefPath.hasPrefix("https://") {
                        if let url = URL(string: hrefPath), let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path {
                            hrefPath = path
                        }
                    }
                    
                    // Normalize paths for comparison
                    let normalizedHref = hrefPath.hasSuffix("/") ? String(hrefPath.dropLast()) : hrefPath
                    let normalizedPath = cleanPath.hasSuffix("/") ? String(cleanPath.dropLast()) : cleanPath
                    
                    // Skip if it's the current directory itself
                    if normalizedHref == normalizedPath || normalizedHref == cleanPath || hrefPath == cleanPath {
                        return false
                    }
                    return true
                }
                
                DispatchQueue.main.async {
                    completion(filtered)
                }
            }
        }
        task.resume()
    }
    
    // Test connection
    func testConnection(completion: @escaping (Bool, String?) -> Void) {
        let cleanHost = config.host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: cleanHost + "/") else {
            completion(false, "无效的主机地址")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.addValue("0", forHTTPHeaderField: "Depth") // Depth 0 for testing
        
        let loginString = String(format: "%@:%@", config.username, config.password)
        guard let loginData = loginString.data(using: .utf8) else {
            completion(false, "认证信息错误")
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "连接失败: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
                    completion(true, nil)
                } else if httpResponse.statusCode == 401 {
                    completion(false, "认证失败：用户名或密码错误")
                } else if httpResponse.statusCode == 404 {
                    completion(false, "服务器未找到")
                } else {
                    completion(false, "服务器返回错误: \(httpResponse.statusCode)")
                }
            } else {
                completion(false, "无效的服务器响应")
            }
        }
        task.resume()
    }
    
    // Recursively list directory and all subdirectories
    func listDirectory(path: String, completion: @escaping ([UnifiedMediaItem]) -> Void) {
        listDirectoryRecursive(path: path, allItems: [], completion: completion)
    }
    
    private func listDirectoryRecursive(path: String, allItems: [UnifiedMediaItem], completion: @escaping ([UnifiedMediaItem]) -> Void) {
        // Construct URL
        let cleanHost = config.host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // Ensure path starts with /
        let cleanPath = path.hasPrefix("/") ? path : "/" + path
        
        guard let url = URL(string: cleanHost + cleanPath) else {
            print("WebDAV listDirectory: Invalid URL - host: \(cleanHost), path: \(cleanPath)")
            DispatchQueue.main.async {
                completion(allItems)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.addValue("1", forHTTPHeaderField: "Depth") // Depth 1 to get immediate children
        
        // Basic Auth
        let loginString = String(format: "%@:%@", config.username, config.password)
        guard let loginData = loginString.data(using: .utf8) else {
            print("WebDAV listDirectory: Failed to encode credentials")
            DispatchQueue.main.async {
                completion(allItems)
            }
            return
        }
        let base64LoginString = loginData.base64EncodedString()
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            // Check for network error first
            if let error = error {
                print("WebDAV listDirectory Network Error: \(error.localizedDescription)")
                print("WebDAV listDirectory Error Code: \((error as NSError).code)")
                print("WebDAV listDirectory Error Domain: \((error as NSError).domain)")
                DispatchQueue.main.async {
                    completion(allItems)
                }
                return
            }
            
            // Check HTTP response status
            guard let httpResponse = response as? HTTPURLResponse else {
                print("WebDAV listDirectory: Invalid response type")
                DispatchQueue.main.async {
                    completion(allItems)
                }
                return
            }
            
            // Check for successful status codes
            guard httpResponse.statusCode == 200 || httpResponse.statusCode == 207 else {
                print("WebDAV listDirectory HTTP Error: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("WebDAV listDirectory Error Response Body: \(responseString.prefix(1000))")
                } else {
                    print("WebDAV listDirectory: No error response body (data is nil)")
                }
                DispatchQueue.main.async {
                    completion(allItems)
                }
                return
            }
            
            // Check for data - even though Content-Length shows 7092, data might be nil
            // This could happen if the connection was interrupted or there's a URLSession issue
            let contentLength = httpResponse.allHeaderFields["Content-Length"] as? String ?? "unknown"
            guard let data = data, data.count > 0 else {
                print("WebDAV listDirectory: No data received (HTTP \(httpResponse.statusCode))")
                print("WebDAV listDirectory: Data is nil or empty (Content-Length header shows \(contentLength) bytes)")
                print("WebDAV listDirectory: This might be a URLSession configuration issue")
                DispatchQueue.main.async {
                    completion(allItems)
                }
                return
            }
            
            // Check for self before parsing
            guard let self = self else {
                print("WebDAV listDirectory: Self is nil (WebDAVClient was deallocated)")
                DispatchQueue.main.async {
                    completion(allItems)
                }
                return
            }
            
            self.parseWebDAVResponse(data) { resources in
                // Filter out the current directory itself
                let filtered = resources.filter { res in
                    var hrefPath = res.href
                    // If href is absolute URL, extract path component
                    if hrefPath.hasPrefix("http://") || hrefPath.hasPrefix("https://") {
                        if let url = URL(string: hrefPath), let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path {
                            hrefPath = path
                        }
                    }
                    
                    // Normalize paths for comparison
                    let normalizedHref = hrefPath.hasSuffix("/") ? String(hrefPath.dropLast()) : hrefPath
                    let normalizedPath = cleanPath.hasSuffix("/") ? String(cleanPath.dropLast()) : cleanPath
                    
                    // Skip if it's the current directory itself
                    if normalizedHref == normalizedPath || normalizedHref == cleanPath || hrefPath == cleanPath {
                        return false
                    }
                    return true
                }
                
                let items = filtered.compactMap { res -> UnifiedMediaItem? in
                    // Skip directories
                    if res.isDirectory { 
                        return nil 
                    }
                    
                    let type: MediaType
                    let lowerType = res.contentType.lowercased()
                    
                    if lowerType.contains("image") {
                        type = .image
                    } else if lowerType.contains("video") {
                        type = .video
                    } else {
                        // Extension fallback
                        let ext = (res.href as NSString).pathExtension.lowercased()
                        if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
                            type = .image
                        } else if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
                            type = .video
                        } else {
                            print("  Skipping unknown file type: \(res.href), content-type: \(res.contentType), ext: \(ext)")
                            return nil
                        }
                    }
                    
                    // Construct full URL for the asset
                    // Href is usually absolute path like /home/Photos/img.jpg
                    // We need to append to host
                    let fullURLString = cleanHost + res.href
                    guard let itemURL = URL(string: fullURLString) else {
                        print("  Failed to create URL from: \(fullURLString)")
                        return nil
                    }
                    
                    return UnifiedMediaItem(url: itemURL, type: type, date: res.lastModified)
                }
                
                // Collect all items so far
                var collectedItems = allItems
                collectedItems.append(contentsOf: items)
                
                // Find all subdirectories to recurse into
                let subdirectories = filtered.filter { $0.isDirectory }
                
                // If no subdirectories, we're done
                guard !subdirectories.isEmpty else {
                    DispatchQueue.main.async {
                        completion(collectedItems)
                    }
                    return
                }
                
                // Recursively process each subdirectory
                let dispatchGroup = DispatchGroup()
                var finalItems = collectedItems  // Start with items from current directory
                let itemsLock = NSLock()
                
                for subdir in subdirectories {
                    dispatchGroup.enter()
                    var subdirPath = subdir.href
                    
                    // Normalize subdirectory path
                    if !subdirPath.hasPrefix("/") && !subdirPath.hasPrefix("http://") && !subdirPath.hasPrefix("https://") {
                        // Relative path, make it absolute
                        let basePath = cleanPath.hasSuffix("/") ? String(cleanPath.dropLast()) : cleanPath
                        subdirPath = basePath + "/" + subdirPath
                    } else if subdirPath.hasPrefix("http://") || subdirPath.hasPrefix("https://") {
                        // Extract path from full URL
                        if let url = URL(string: subdirPath), let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path {
                            subdirPath = path
                        }
                    }
                    
                    // Ensure path doesn't have trailing slash (except root)
                    if subdirPath != "/" && subdirPath.hasSuffix("/") {
                        subdirPath = String(subdirPath.dropLast())
                    }
                    
                    // Pass empty array to subdirectory, it will return its own items
                    self.listDirectoryRecursive(path: subdirPath, allItems: [], completion: { subItems in
                        itemsLock.lock()
                        // Append items from this subdirectory to finalItems
                        finalItems.append(contentsOf: subItems)
                        itemsLock.unlock()
                        dispatchGroup.leave()
                    })
                }
                
                // Wait for all subdirectories to complete
                dispatchGroup.notify(queue: .main) {
                    completion(finalItems)
                }
            }
        }
        task.resume()
    }
    
    private func parseWebDAVResponse(_ data: Data, completion: @escaping ([WebDAVResource]) -> Void) {
        resources = []
        parseCompletion = completion
        let parser = XMLParser(data: data)
        parser.delegate = self
        let success = parser.parse()
        if !success {
            print("WebDAV: XML parsing failed")
            if let parseError = parser.parserError {
                print("WebDAV: Parser error: \(parseError.localizedDescription)")
            }
            // Still call completion with empty array if parsing fails
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName.hasSuffix("response") { // Handle d:response
            currentHref = ""
            currentContentType = ""
            currentLastModified = ""
            currentIsCollection = false
        } else if elementName == "collection" || (elementName.hasSuffix("collection") && elementName.contains("resourcetype")) {
            // Mark as collection when we see <D:collection/> or <collection/> tag
            currentIsCollection = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        
        if currentElement.hasSuffix("href") {
            currentHref += trimmed
        } else if currentElement.hasSuffix("getcontenttype") {
            currentContentType += trimmed
        } else if currentElement.hasSuffix("getlastmodified") {
            currentLastModified += trimmed
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.hasSuffix("response") {
            // Only add resource if href is not empty
            guard !currentHref.isEmpty else {
                print("WebDAV: Skipping resource with empty href")
                return
            }
            
            // Parse date
            let dateFormatter = DateFormatter()
            // WebDAV typically uses RFC 1123 format: Mon, 12 Dec 2025 10:00:00 GMT
            dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss zzz"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let date = dateFormatter.date(from: currentLastModified)
            
            // Create resource with collection flag
            let res = WebDAVResource(href: currentHref, contentType: currentContentType, lastModified: date, isCollection: currentIsCollection)
            resources.append(res)
        } else if elementName.hasSuffix("multistatus") {
            // Parsing complete
            if let completion = parseCompletion {
                completion(resources)
            }
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("WebDAV XML Parse Error: \(parseError.localizedDescription)")
        if let completion = parseCompletion {
            DispatchQueue.main.async {
                completion([])
            }
        }
    }
    
    // Helper to get authenticated URLRequest for an item (for image loading)
    func authenticatedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        let loginString = String(format: "%@:%@", config.username, config.password)
        if let loginData = loginString.data(using: .utf8) {
            let base64LoginString = loginData.base64EncodedString()
            request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}


