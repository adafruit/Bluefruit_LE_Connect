//
//  AttributeCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/20/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import UIKit

class AttributeCell: UITableViewCell {
    
    var label:UILabel!
    var button:UIButton!
    var dataStrings:[String]! {
        didSet {
            var string:String = ""
            for i in 0...(dataStrings.count-1) {
                if i == 0 {
                    string = " \(dataStrings[i]):"
                }
                else {
                    string += " \(dataStrings[i])"
                }
            }
            self.label?.text = string
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
