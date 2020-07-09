//
//  SVGALoader.swift
//  Pods
//
//  Created by clovelu on 2020/7/2.
//

import Foundation

public typealias CompletionHandler = ((_ svga: SVGAMovieEntity?, _ error: Error?, _ url: URL) -> Void)

open class SVGAManager: NSObject {
    public static let shared = SVGAManager()
    open lazy var session: URLSession = {
        let path =  "com.swift.svga.cache"
        let cache = URLCache(memoryCapacity: 1024 * 1024 * 10, diskCapacity: 1024 * 1024 * 500, diskPath: path)
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = cache
        
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        return session
    }()
    
    public let cache: NSCache = NSCache<NSString, SVGAMovieEntity>()
    public private(set) var unionTaskCache = UnionTaskCache()
    public let processQueue = DispatchQueue(label: "com.swift.svga.manager.process", attributes: .concurrent)
    
    open func download(urlString: String?, handle: @escaping CompletionHandler) -> LoadTask? {
        guard let urlString = urlString else { return nil }
        guard let url = URL(string: urlString) else { return nil }
        return download(url: url, handle: handle)
    }
    
    open func download(url: URL?, handle: @escaping CompletionHandler) -> LoadTask? {
        guard let tURL = url else { return nil }
        
        let key: NSString = tURL.absoluteString.md5String() as NSString
        let svga = self.cache.object(forKey: key)
        if svga != nil {
            DispatchQueue.main.async {
                handle(svga, nil, tURL)
            }
            return nil
        }
        
        let unionTask = unionTaskCache.get(for: key)
        if unionTask != nil {
            return unionTask?.enqueue(handle: handle)
        }
        
        if tURL.isFileURL {
            return loadLocal(url: tURL, key: key, handle: handle)
        }
        
        let loadTask = self.downloadRemote(url: tURL, key: key, handle: handle)
        return loadTask
    }
    
    func loadLocal(url: URL, key: NSString, handle: CompletionHandler?) -> LoadTask? {
        guard url.isFileURL == true else { return nil }
        
        let unionTask = unionTaskCache.obtained(for: key)
        let loadTask = handle != nil ? unionTask.enqueue(handle: handle) : nil
        
        self.processQueue.async {
            do {
                let svga = try SVGAMovieEntity(fileURL: url)
                if svga.version.count > 0 {
                    self.cache.setObject(svga, forKey: key)
                }
                
                unionTask.finshed(svga: svga, error: nil, url: url)
            } catch {
                unionTask.finshed(svga: nil, error: error, url: url)
            }
        }
        
        return loadTask
    }
    
    func downloadRemote(url: URL, key: NSString, handle: @escaping CompletionHandler) -> LoadTask? {
        let key = url.absoluteString.md5String() as NSString
        
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        
        let unionTask = unionTaskCache.obtained(for: key)
        let loadTask = unionTask.enqueue(handle: handle)
        
        let task = session.dataTask(with: req) { (data, response, error) in
            unionTask.sessionTask = nil
            if data != nil {
                self.processQueue.async {
                    do {
                        let svga = try SVGAMovieEntity(data: data!)
                        if svga.version.count > 0 {
                            self.cache.setObject(svga, forKey: key)
                        }
                    
                        unionTask.finshed(svga: svga, error: nil, url: url)
                    } catch {
                        unionTask.finshed(svga: nil, error: error, url: url)
                    }
                }
            } else {
                unionTask.finshed(svga: nil, error: error, url: url)
            }
        }

        unionTask.sessionTask = task
        task.resume()
        return loadTask
    }
}

extension SVGAManager {
    public class UnionTaskCache {
        var unionTaskCache: [NSString: UnionTask] = [:]
        var lock = NSLock()
        
        func obtained(for key: NSString) -> UnionTask {
            var task = self.get(for: key)
            if task == nil {
                task = UnionTask(key: key, lock: self.lock)
                set(task, key: key)
            }
            return task!
        }
        
        func get(for key: NSString) -> UnionTask? {
            lock.lock()
            defer { lock.unlock() }
            let contextTask = unionTaskCache[key]
            return contextTask
        }
        
        func set(_ unionTask: UnionTask?, key: NSString) {
            lock.lock()
            if unionTask != nil {
                unionTask?.onFinshedHandle = {[weak self] (_, cancel) in
                    self?.unionTaskCache.removeValue(forKey: key)
                }
                unionTaskCache[key] = unionTask!
            } else {
                unionTaskCache.removeValue(forKey: key)
            }
            lock.unlock()
        }
    }
    
    public class LoadTask {
        private(set) weak var task: UnionTask?
        var handle: CompletionHandler?
        
        init(task: UnionTask, handle: CompletionHandler?) {
            self.task = task
            self.handle = handle
        }
        
        func cancel() {
            handle = nil
            task?.cancel(task: self)
        }
    }
    
    
    public class UnionTask {
        var key: NSString
        var sessionTask: URLSessionTask?
        var callBackTasks: [LoadTask] = []
        var lock: NSLock
        
        var onFinshedHandle: ((_ key:NSString, _ isCancel: Bool) -> Void)?
        var isCancel: Bool = false
        
        init(key: NSString, lock: NSLock) {
            self.key = key
            self.lock = lock
        }
        
        init(task: URLSessionTask?, key: NSString, lock: NSLock) {
            self.key = key
            sessionTask = task
            self.lock = lock
        }
        
        func enqueue(handle: CompletionHandler?) -> LoadTask {
            lock.lock()
            let loadTask = LoadTask(task: self, handle: handle)
            callBackTasks.append(loadTask)
            lock.unlock()
            return loadTask
        }
        
        func cancel(task: LoadTask) {
            lock.lock()
            callBackTasks.removeAll { (loadTask) -> Bool in
                return task === loadTask
            }
            if callBackTasks.count == 0 {
                sessionTask?.cancel()
                self.isCancel = true
                self.onFinshedHandle?(self.key, true)
            }
            lock.unlock()
        }
        
        func finshed(svga: SVGAMovieEntity?, error: Error?, url: URL) {
            lock.lock()
            let list = self.callBackTasks
            self.callBackTasks = []
            self.onFinshedHandle?(self.key, false)
            lock.unlock()
            
            DispatchQueue.main.async {
                list.forEach { (task) in
                    task.handle?(svga, error, url)
                }
            }
        }
    }
}
