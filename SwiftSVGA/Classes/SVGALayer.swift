//
//  SVGALayer.swift
//  Pods
//
//  Created by clovelu on 2020/7/1.
//

import UIKit
import QuartzCore

open class SVGABitmapLayer: CALayer {
    open var image: UIImage? {
        didSet {
            self.contents = image?.cgImage
            self.isHidden = (image == nil)
        }
    }
    
    override public init() {
        super.init()
        self.masksToBounds = true
        self.backgroundColor = UIColor.clear.cgColor
        self.contentsGravity = kCAGravityResizeAspect
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.masksToBounds = true
        self.backgroundColor = UIColor.clear.cgColor
        self.contentsGravity = kCAGravityResizeAspect
    }
}

open class SVGAShapeLayer: CAShapeLayer {
    open func draw(shape: SVGAShapeEntity) {
        self.backgroundColor = UIColor.clear.cgColor
        self.path = (shape.bezierPath ?? UIBezierPath()).cgPath
        
        let styles = shape.styles ?? SVGAShapeEntity.ShapeStyle()
        self.fillColor = styles.fillColor?.cgColor
        self.strokeColor = styles.strokeColor?.cgColor ?? UIColor.black.cgColor
        self.lineWidth = styles.strokeWidth
        self.lineCap = styles.lineCap as String
        self.lineJoin = styles.lineJoin as String
        self.lineDashPhase = styles.lineDashPhase
        self.lineDashPattern = styles.lineDashPattern as [NSNumber]?
        self.miterLimit = styles.miterLimit
        self.transform = CATransform3DMakeAffineTransform(shape.transform)
    }
}

open class SVGAVectorLayer: CALayer {
    open var shapeLayers: [SVGAShapeLayer] = []
    open var shapeLayersReuses: [SVGAShapeLayer] = []
    
    open func draw(shapes: [SVGAShapeEntity]?) {
        shapeLayers.forEach { (layer) in
            layer.isHidden = true
        }
        
        shapeLayersReuses += shapeLayers
        
        shapeLayers = shapes?.compactMap({ (shapeEntity) -> SVGAShapeLayer? in
            return obtainShapLayer(shapeEntity)
        }) ?? []
    }
    
    func obtainShapLayer(_ shapeEntity: SVGAShapeEntity) -> SVGAShapeLayer {
        var layer: SVGAShapeLayer!
        if shapeLayersReuses.count > 0 {
            layer = shapeLayersReuses.removeFirst()
        } else {
            layer = SVGAShapeLayer()
        }
        
        self.addSublayer(layer)
        layer.isHidden = false
        layer.draw(shape: shapeEntity)
        return layer
    }
}


open class SVGASpriteLayer: CALayer {
    open var spriteEntity: SVGASpriteEntity?
    public private(set) var vectorLayer: SVGAVectorLayer?
    public private(set) var bitmapLayer: SVGABitmapLayer?
    public private(set) var maskLayer: CAShapeLayer?
    
    override open var frame: CGRect {
        didSet {
             bitmapLayer?.frame = self.bounds
        }
    }
    
    open var image: UIImage? {
        didSet {
            if image != nil && bitmapLayer == nil {
                bitmapLayer = SVGABitmapLayer()
                bitmapLayer?.frame = self.bounds
                self.addSublayer(bitmapLayer!)
            }
            bitmapLayer?.image = image
        }
    }
    
    open var dynamicHidden: Bool = false {
        didSet {
            self.isHidden = dynamicHidden
        }
    }
    
    open func step(index: Int) {
        guard !dynamicHidden else { return }
        guard let frameEntity = self.spriteEntity?.frame(at: index) else {
            self.isHidden = true
            return
        }
        draw(frameEntity: frameEntity)
    }
    
    open func draw(frameEntity: SVGAFrameEntity) {
        self.opacity = Float(frameEntity.alpha)
        if self.opacity <= 0.01 { return }
        self.position = .zero
        self.transform = CATransform3DIdentity
        self.frame = frameEntity.layout
        self.transform = CATransform3DMakeAffineTransform(frameEntity.transform)
        
        let offsetX = self.frame.origin.x - frameEntity.nx
        let offsetY = self.frame.origin.y - frameEntity.ny
        self.position = CGPoint(x: self.position.x - offsetX, y: self.position.y - offsetY)
        
        drawMask(frameEntity: frameEntity)
        drawVectorLayer(frameEntity: frameEntity)
    }
    
    open func drawMask(frameEntity: SVGAFrameEntity) {
        if frameEntity.clipBezierPath != nil {
            if maskLayer == nil {
                maskLayer = CAShapeLayer()
                maskLayer?.fillColor = UIColor.black.cgColor
                self.mask = maskLayer
            }
            maskLayer?.path = frameEntity.clipBezierPath?.cgPath
        } else {
            self.mask = nil
        }
    }
    open func drawVectorLayer(frameEntity: SVGAFrameEntity) {
        if frameEntity.shapes.count > 0 {
            if vectorLayer == nil {
                vectorLayer = SVGAVectorLayer()
                self.addSublayer(vectorLayer!)
            }
            vectorLayer?.isHidden = false
            vectorLayer?.draw(shapes: frameEntity.shapes)
        } else {
            vectorLayer?.isHidden = true
        }
    }
}
