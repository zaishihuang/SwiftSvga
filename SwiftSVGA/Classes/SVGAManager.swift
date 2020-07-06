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
        let path =  "/com.swift.svga.cache"
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
        let key: NSString = tURL.absoluteString as NSString
        let svga = self.cache.object(forKey: key)
        if svga != nil {
            DispatchQueue.main.async {
                handle(svga, nil, tURL)
            }
            return nil
        }
        
        var loadTask = unionTaskCache.fetch(for: key, handle: handle, task: nil)
        if loadTask != nil {
            return loadTask
        }
        
        let cachePolicy: URLRequest.CachePolicy = tURL.isFileURL ? .reloadIgnoringCacheData : .returnCacheDataElseLoad
        let req = URLRequest(url: tURL, cachePolicy: cachePolicy, timeoutInterval: 60)
        let task = session.dataTask(with: req) { [weak self] (data, response, error) in
            if error != nil {
                let unionTask = self?.unionTaskCache.pod(for: key)
                unionTask?.finshed(svga: nil, error: error, url: tURL)
                return
            }
            
            self?.processQueue.async {
                do {
                    let svga = data != nil ? try SVGAMovieEntity(data: data!) : nil
                    if svga != nil {
                        self?.cache.setObject(svga!, forKey: key)
                    }
                    let unionTask = self?.unionTaskCache.pod(for: key)
                    unionTask?.finshed(svga: svga, error: error, url: tURL)
                } catch {
                    let unionTask = self?.unionTaskCache.pod(for: key)
                    unionTask?.finshed(svga: nil, error: error, url: tURL)
                }
            }
        }
        
        loadTask = unionTaskCache.fetch(for: key, handle: handle, task: task)
        task.resume()
        return loadTask
    }
}

extension SVGAManager {
    public class UnionTaskCache {
        var unionTaskCache: [NSString: UnionTask] = [:]
        var lock = NSLock()
        
        func fetch(for key: NSString, handle:@escaping CompletionHandler, task: URLSessionTask?) -> LoadTask? {
            var unionTask = get(for: key)
            if unionTask == nil && task != nil {
                unionTask = UnionTask(task: task!, key: key, lock: lock)
                set(contextTask: unionTask, key: key)
            }
            return unionTask?.enqueue(handle: handle)
        }
        
        func pod(for key: NSString) -> UnionTask? {
            let task = self.get(for: key)
            set(contextTask: nil, key: key)
            return task
        }
        
        func get(for key: NSString) -> UnionTask? {
            lock.lock()
            defer { lock.unlock() }
            let contextTask = unionTaskCache[key]
            return contextTask
        }
        
        func set(contextTask: UnionTask?, key: NSString) {
            lock.lock()
            if contextTask != nil {
                contextTask?.onCancelHandle = {[weak self] tKey in
                    self?.set(contextTask: nil, key: tKey)
                }
                unionTaskCache[key] = contextTask!
            } else {
                unionTaskCache.removeValue(forKey: key)
            }
            lock.unlock()
        }
//
//        func remove(for key: NSString) {
//            set(contextTask: nil, key: key)
//        }
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
        var onCancelHandle: ((_ key:NSString) -> Void)?
        var lock: NSLock
        
        init(task: URLSessionTask, key: NSString, lock: NSLock) {
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
                self.onCancelHandle?(self.key)
            }
            lock.unlock()
        }
        
        func finshed(svga: SVGAMovieEntity?, error: Error?, url: URL) {
            lock.lock()
            let list = self.callBackTasks
            self.callBackTasks = []
            lock.unlock()
            
            DispatchQueue.main.async {
                list.forEach { (task) in
                    task.handle?(svga, error, url)
                }
            }
        }
    }
}
