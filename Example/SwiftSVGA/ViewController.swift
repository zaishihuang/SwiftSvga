//
//  ViewController.swift
//  SwiftSVGA
//
//  Created by zaishi on 06/24/2020.
//  Copyright (c) 2020 zaishi. All rights reserved.
//

import UIKit
import SwiftSVGA

class ViewController: UIViewController {
    let svgaView = SVGAView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        svgaView.frame = CGRect(x: 0, y: 100, width: self.view.frame.size.width, height: 300)
        svgaView.layer.borderWidth = 1
        self.view.addSubview(svgaView)
        
//        let url = Bundle.main.url(forResource: "EmptyState", withExtension: "svga")
        let url = Bundle.main.url(forResource: "rose", withExtension: "svga")
        svgaView.setURL(url)
        
//        let data = try? Data(contentsOf: url!)
//        do {
//            let svga = try SVGAMovieEntity(data: data!)
//            svgaView.movieEntity = svga
//        } catch {
//            print(error)
//        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

