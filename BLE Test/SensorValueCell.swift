//
//  SensorValueCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 12/5/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import UIKit

class SensorValueCell: UITableViewCell {
    
    var valueLabel:UILabel!
    
    var prefixString:String = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    
    func updateValue(newVal:Float){
        
        self.valueLabel.text = prefixString + ": \(newVal)"
        
    }
    
}
