//
//  ArucoNode.swift
//  ARWorldTracking
//
//  Created by Bobby on 4/8/21.
//

import Foundation
import ARKit

class ArucoNode : SCNNode {
    var size:CGFloat;
    public let id:Int;

    init(sz:CGFloat = 0.04, arucoId:Int = 23) {
        self.size = CGFloat(Float(ArucoProperty.ArucoMarkerSize));
        self.id = arucoId;
        
        super.init();

        self.geometry = SCNBox(width: size, height: size, length: size, chamferRadius: 0)
        let mat = SCNMaterial()
        self.geometry?.materials = [mat]
        
        let hue = CGFloat((id * 3) % 250);
        let color: UIColor = UIColor.colorWithHSV(hue: hue, saturation: 1, value: 1)!
        mat.diffuse.contents = color
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
