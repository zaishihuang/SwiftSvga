//
//  SVGAView.swift
//  Pods
//
//  Created by clovelu on 2020/6/30.
//

import UIKit
import QuartzCore

open class SVGAView: UIView {
    public typealias OnDidLoadHandle = ((_ view: SVGAView, _ svga: SVGAMovieEntity?) -> Void)
    public typealias OnUpdateHandle = ((_ view: SVGAView, _ curIndex: Int, _ curLoop: Int) -> Void)
    public typealias OnAnimatingChangeHandle = ((_ view: SVGAView, _ new:Bool, _ old: Bool) -> Void)
    public typealias OnPlayFinshedHandle = ((_ view: SVGAView, _ loop:Int) -> Void)
    
    public class WeakLinkDelegate: NSObject {
        weak var base: SVGAView?
        init(_ base: SVGAView?) {
            self.base = base
        }
        @objc public func step(link:CADisplayLink) {
            base?.step(link: link)
        }
    }
    
    public private(set) var displayLink: CADisplayLink?
    public private(set) lazy var drawLayer: CALayer = {
        let layer = CALayer()
        layer.masksToBounds = true
        self.layer.addSublayer(layer)
        return layer
    }()
    public private(set) var spriteLayers: [SVGASpriteLayer] = []
    public private(set) var spriteLayersReuses: [SVGASpriteLayer] = []
    
    open private(set) var dynamicImages: [String: UIImage] = [:]
    open private(set) var dynamicHiddens: [String: Bool] = [:]
    
    open var autoPlayIfMove: Bool = true
    open var fillModel: FillModel = .forwards
    open var totalLoop: Int = 0
    open private(set) var curIndex: Int = 0
    open private(set) var curLoop: Int = 0
    open private(set) var totalFrameCount: Int = 0
    open private(set) var isAnimating: Bool = false {
        didSet {
            if isAnimating != oldValue {
                self.onAnimatingChangeHandle?(self, isAnimating, oldValue)
            }
        }
    }
    
    open private(set) var url: URL?
    open private(set) var task: SVGAManager.LoadTask?
    
    open var onDidLoadHandle: OnDidLoadHandle?
    open var onDidUpdateHandle: OnUpdateHandle?
    open var onAnimatingChangeHandle: OnAnimatingChangeHandle?
    open var onPlayFinshedHandle: OnPlayFinshedHandle?
    
    open var movieEntity: SVGAMovieEntity? {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            reset()
            CATransaction.commit()
            
            self.onDidLoadHandle?(self, movieEntity)
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.contentMode = .scaleAspectFit
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.contentMode = .scaleAspectFit
    }
    
    deinit {
        displayLink?.isPaused = true
        displayLink = nil
        if task != nil {
            cancelLoading()
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        resize()
    }
    
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        didMove()
    }
    
    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        didMove()
    }
        
    open func reset() {
        stopAnimation()
        drawLayer.sublayers?.forEach({ (layer) in
            layer.removeFromSuperlayer()
        })
        spriteLayersReuses += spriteLayers
        spriteLayers = []
        curLoop = 0
        curIndex = 0
        totalFrameCount = movieEntity?.frames ?? 0
    
        drawLayer.isHidden = (movieEntity == nil)
        resize()
        
        if movieEntity != nil {
            spriteLayers = movieEntity?.sprites.compactMap({ (spriteEntity) -> SVGASpriteLayer? in
                let key = spriteEntity.imageKey
                let layer: SVGASpriteLayer = {
                    if spriteLayersReuses.count > 0 {
                        return spriteLayersReuses.removeFirst()
                    }
                    return SVGASpriteLayer()
                }()
                layer.spriteEntity = spriteEntity
                layer.image = dynamicImages[key] ?? movieEntity?.image(for: key)
                layer.dynamicHidden = dynamicHiddens[key] ?? false
                drawLayer.addSublayer(layer)
                
                return layer
            }) ?? []

            update()
            
            if displayLink == nil {
                displayLink = CADisplayLink(target: WeakLinkDelegate(self), selector: #selector(step(link:)))
                displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
                displayLink?.isPaused = true
            }
            displayLink?.frameInterval = 60 / max(movieEntity!.fps, 1)
            startAnimation()
        }
    }
    
    open func startAnimation() {
        startAnimation(at: 0)
    }
    
    open func startAnimation(at index: Int) {
        if isAnimating { return }
        if self.window == nil || self.superview == nil { return }
        if index >= totalFrameCount { return }
        
        let needUpdate = drawLayer.isHidden || (curIndex != index)
        drawLayer.isHidden = false
        isAnimating = true
        curIndex = index
        curLoop = 0
        if needUpdate { update() }
        displayLink?.isPaused = false
    }
    
    open func stopAnimation() {
        if isAnimating {
            isAnimating = false
            displayLink?.isPaused = true
        }
    }
    
    @objc open func step(link:CADisplayLink) {
        guard let _ = self.movieEntity else {
            stopAnimation()
            return
        }
        
        let nIdx = curIndex + 1
        if nIdx >= totalFrameCount {
            curLoop += 1
            if totalLoop > 0 && curLoop >= totalLoop {
                stopAnimation()
                playDidFinshed()
                return
            }
        }
        
        curIndex = nIdx % totalFrameCount
        self.update()
    }
    
    open func playDidFinshed() {
        switch fillModel {
        case .forwards:break
        case .backwards:
            moveFrame(to: 0)
        case .clear:
            drawLayer.isHidden = true
        }
        
        self.onPlayFinshedHandle?(self, curLoop)
    }
    
    open func moveFrame(to index: Int, play: Bool = false) {
        if index >= totalFrameCount || index == self.curIndex { return }

        drawLayer.isHidden = false
        curIndex = index
        update()
        
        if play && !isAnimating {
            self.startAnimation(at: index)
        }
    }
    
    open func update() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.spriteLayers.forEach { layer in
            layer.step(index: curIndex)
        }
        CATransaction.commit()
        self.onDidUpdateHandle?(self, curIndex, curLoop)
    }
    
    open func resize() {
        guard let movieEntity = self.movieEntity else {
            drawLayer.frame = CGRect.zero
            return
        }
        
        let size = self.bounds.size
        let videoSize = movieEntity.size
        let videoRatio = videoSize.width / videoSize.height
        let layerRatio = size.width / size.height
        
        drawLayer.transform = CATransform3DIdentity
        drawLayer.frame = CGRect(origin: .zero, size: movieEntity.size)
        
        switch self.contentMode {
        case .scaleAspectFit:
            if videoRatio > layerRatio {
                let ratio = size.width / videoSize.width
                let offset = CGPoint(x: (1.0 - ratio) / 2.0 * videoSize.width,
                                     y: (1.0 - ratio) / 2.0 * videoSize.height
                                     - (size.height - videoSize.height * ratio) / 2.0)
                drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: ratio, b: 0, c: 0, d: ratio, tx: -offset.x, ty: -offset.y))
            } else {
                let ratio = size.height / videoSize.height
                let offset = CGPoint(x: (1.0 - ratio) / 2.0 * videoSize.width - (size.width - videoSize.width * ratio) / 2.0,
                                     y: (1.0 - ratio) / 2.0 * videoSize.height)
                drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: ratio, b: 0, c: 0, d: ratio, tx: -offset.x, ty: -offset.y))
            }
        case .scaleAspectFill:
            if videoRatio < layerRatio {
                let ratio = size.width / videoSize.width
                let offset = CGPoint(x: (1.0 - ratio) / 2.0 * videoSize.width,
                                     y: (1.0 - ratio) / 2.0 * videoSize.height
                                               - (size.height - videoSize.height * ratio) / 2.0
                                               )
                drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: ratio, b: 0, c: 0, d: ratio, tx: -offset.x, ty: -offset.y))
              } else {
                let ratio = size.height / videoSize.height
                let offset = CGPoint(x: (1.0 - ratio) / 2.0 * videoSize.width - (size.width - videoSize.width * ratio) / 2.0,
                                         y: (1.0 - ratio) / 2.0 * videoSize.height)
                self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: ratio, b: 0, c: 0, d: ratio, tx: -offset.x, ty: -offset.y))
            }
        case .top:
            let scaleX = size.width / videoSize.width
            let offset = CGPoint(x: (1.0 - scaleX) / 2.0 * videoSize.width,
                                     y: (1 - scaleX) / 2.0 * videoSize.height)
            drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleX, tx: -offset.x, ty: -offset.y))
        case .bottom:
            let scaleX = size.width / videoSize.width
            let offset = CGPoint(x: (1.0 - scaleX) / 2.0 * videoSize.width,
                                 y: (1.0 - scaleX) / 2.0 * videoSize.height)
            drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleX, tx: -offset.x, ty: -offset.y + size.height - videoSize.height * scaleX))
        case .left:
            let scaleY = size.height / videoSize.height
            let offset = CGPoint(x: (1.0 - scaleY) / 2.0 * videoSize.width,
                                 y: (1 - scaleY) / 2.0 * videoSize.height)
            drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: scaleY, b: 0, c: 0, d: scaleY, tx: -offset.x, ty: -offset.y))
        case .right:
            let scaleY = size.height / videoSize.height
            let offset = CGPoint(x: (1.0 - scaleY) / 2.0 * videoSize.width,
                                 y: (1.0 - scaleY) / 2.0 * videoSize.height)
            drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: scaleY, b: 0, c: 0, d: scaleY, tx: -offset.x + size.width - videoSize.width * scaleY,ty: -offset.y))
        default:
            let scaleX = size.width / videoSize.width
            let scaleY = size.height / videoSize.height
            let offset = CGPoint(x: (1.0 - scaleX) / 2.0 * videoSize.width,
                                     y: (1 - scaleY) / 2.0 * videoSize.height)
            self.drawLayer.transform = CATransform3DMakeAffineTransform(CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleY, tx: -offset.x, ty: -offset.y))
        }
    }
    
    open func didMove() {
        if self.autoPlayIfMove {
            if self.superview != nil && self.window != nil {
                 self.startAnimation()
            } else {
                self.stopAnimation()
            }
        }
    }
}

protocol SVGAViewDynamicable {
    func setImage(_ image:UIImage?, key:String)
    func setHidden(_ hidden:Bool, key:String)
    func clearDynamic()
}

extension SVGAView: SVGAViewDynamicable {
    func setImage(_ image:UIImage?, key:String) {
        if image == nil {
            dynamicImages.removeValue(forKey: key)
        } else {
            dynamicImages[key] = image
        }
        
        spriteLayers.filter { (layer) -> Bool in
            return layer.spriteEntity?.imageKey == key
        }.forEach { (layer) in
            layer.image = image
        }
    }
    
    func setHidden(_ hidden:Bool, key:String) {
        dynamicHiddens[key] = hidden
        spriteLayers.filter { (layer) -> Bool in
            return layer.spriteEntity?.imageKey == key
        }.forEach { (layer) in
            layer.dynamicHidden = hidden
        }
    }
    
    func clearDynamic() {
        dynamicHiddens = [:]
        dynamicImages = [:]
    }
}


extension SVGAView {
    public enum FillModel {
        case forwards
        case backwards
        case clear
    }
}

extension SVGAView {
    open func setURLString(_ urlString: String?, handle: CompletionHandler? = nil) {
        let url = urlString != nil ? URL(string: urlString!) : nil
        setURL(url, handle: handle)
    }
        
    open func setURL(_ url: URL?, handle: CompletionHandler? = nil) {
        self.url = url
        let task = SVGAManager.shared.download(url: url) { [weak self] (svga, error, tURL) in
            guard url == self?.url else { return }
            self?.task = nil
            if svga != nil {
                self?.movieEntity = svga
            }
            handle?(svga,error,tURL)
        }
        self.task?.cancel()
        self.task = task
    }
    
    open func cancelLoading() {
        task?.cancel()
        task = nil
    }
}
