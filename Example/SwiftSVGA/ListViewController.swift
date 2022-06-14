//
//  ListViewController.swift
//  SwiftSVGA_Example
//
//  Created by clovelu on 2020/7/3.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import SwiftSVGA

class Cell: UICollectionViewCell {
    lazy var svgaView: SVGAView = {
       let view = SVGAView(frame: self.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.contentView.addSubview(view)
        self.contentView.layer.borderWidth = 2
        self.contentView.layer.borderColor = UIColor.white.cgColor
        return view
    }()
    
    func config(_ url: URL?) {
        svgaView.movieEntity = nil
        svgaView.setURL(url) { (svga, error, url) in
            if let svga = svga {
                print("==> svga: \(svga.version) \(svga.size) imageCount:\(svga.images.count) sprites:\(svga.sprites.count)")
            } else {
                print("==> load error: \(String(describing: error))")
            }
        }
    }
}

class ListViewController: UIViewController {

    lazy var items: [String] = [
//                               "https://github.com/yyued/SVGA-Samples/blob/master/EmptyState.svga?raw=true",
                               "http://github.com/yyued/SVGA-Samples/blob/master/HamburgerArrow.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/PinJump.svga?raw=true",
                           
                               "https://github.com/yyued/SVGA-Samples/blob/master/TwitterHeart.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/Walkthrough.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/angel.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/halloween.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/kingset.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/posche.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/rose.svga?raw=true",
                               "https://github.com/yyued/SVGA-Samples/blob/master/EmptyState.svga?raw=true",
                               ]
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        
        let itemWidth = (self.view.frame.size.width - 10) / 2.0
        layout.itemSize = CGSize(width: itemWidth, height: 160)
  
        
        let collectionView = UICollectionView.init(frame: self.view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(Cell.self, forCellWithReuseIdentifier: "cell")
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        self.view.addSubview(collectionView)
    }
}

extension ListViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return 2
        return self.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! Cell
        let urlString = self.items[indexPath.row]
        let url = URL(string: urlString)
        cell.config(url)
        return cell
    }
}
